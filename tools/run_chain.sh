#!/bin/bash
# Launch an N-rank qwen35 pipeline across hosts (last rank first), run the bench on the head, stop everything.
# usage: TREE='C:\ecgbench\shards\q36-3stage' HOSTS="alpha beta charlie" IPS="192.168.0.101 192.168.0.103 192.168.0.188" [DEVICE=GPU] [LISTEN_PORT=9100] TAGS="..." run_chain.sh <label>
set -u
cd "$(dirname "$0")"; source ./hosts.sh
label=$1; read -r -a H <<<"$HOSTS"; read -r -a IP <<<"$IPS"; N=${#H[@]}; DEVICE=${DEVICE:-GPU}; LP=${LISTEN_PORT:-9100}; API=${API:-:8130}
HZ='C:\ecgbench\harness'; R="C:\\ecgbench\\results\\$label"
OUT="/Users/tatef/Workspaces/cascadia-ecg-bench/results/$label"; mkdir -p "$OUT"
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
log() { echo "[$(date +%H:%M:%S)] [chain/$label] $*" | tee -a "$OUT/orchestrator.log"; }
for ((r=N-1; r>=0; r--)); do
  h=${H[$r]}; ps "$h" "New-Item -ItemType Directory -Force -Path '$R' | Out-Null; 'ok'" >/dev/null
  if [ $r -eq $((N-1)) ]; then NEXT=""; else NEXT="-Next ${IP[$((r+1))]}:$LP"; fi
  if [ $r -eq 0 ]; then APIARG="-Api '$API'"; LISTEN=""; else APIARG=""; LISTEN="-Listen :$LP"; fi
  log "launch rank $r on $h $LISTEN $NEXT $APIARG"
  ps "$h" "& '$HZ\\win\\server.ps1' ${EXE:+-Exe '$EXE'} ${ENVS:+-Env '$ENVS'} -Mode worker -Model '$TREE' -Engine qwen35 -Device $DEVICE -Rank $r -Total $N $LISTEN $NEXT $APIARG -CacheDir none -Extra '--prefix-cache-gb 0 ${EXTRA:-}' -Log '$R\\rank$r.log'" | grep -E "CMD|LAUNCH" | tee -a "$OUT/orchestrator.log"
  sleep ${RANK_GAP:-20}
done
# rank 0 host runs the standard measurement sequence (server already launched)
HEAD=${H[0]}
export NOLAUNCH=1 NOSTOP=1 TAGS="${TAGS:-config=$label} stages=$N"
./run_config.sh "$HEAD" "$label"
# per-rank utilization/power snapshot during a second steady loop (ranks 1..N-1 sampled too)
log "chain-wide steady window: samplers + SoC Watch on every rank"
for ((r=0; r<N; r++)); do h=${H[$r]}
  ps "$h" "& '$HZ\\win\\launch.ps1' -Cmd 'powershell -NoProfile -ExecutionPolicy Bypass -File $HZ\\win\\sample.ps1 -Out $R\\steady-rank$r.util.jsonl -Seconds 95' -Log '$R\\sampler-rank$r.log' -Priority Normal" >/dev/null &
done; wait
ps "$HEAD" "& '$HZ\\win\\launch.ps1' -Cmd '\"C:\\ecgbench\\venv\\Scripts\\python.exe\" $HZ\\bench_client.py --base http://127.0.0.1:${API##*:} --mode steady --seconds 90 --steady-prompt medium --max-tokens 256 --out $R\\steady2.jsonl --tag config=$label --tag stages=$N' -Log '$R\\steady2-client.log' -Priority Normal" >/dev/null
sleep 12
for ((r=0; r<N; r++)); do h=${H[$r]}
  ( ps "$h" "& '$HZ\\win\\socwatch_run.ps1' -Seconds 60 -Prefix '$R\\steady-rank$r.sw'" | tail -1 | cut -c1-300 | sed "s/^/rank$r($h): /" | tee -a "$OUT/orchestrator.log" ) &
done; wait; sleep 25
case "$label" in C2*|D*) log "GSM8K eval on the chain head (N=${EVAL_N:-40})"; N=${EVAL_N:-40} TAGS="config=$label stages=$N model=${MODEL_TAG:-q36-35b}" EVAL_TOKENS=${EVAL_TOKENS:-512} EVAL_WAIT_MIN=${EVAL_WAIT_MIN:-120} ./run_eval.sh "$HEAD" "$label-eval";; esac
log "stop all ranks"
for ((r=0; r<N; r++)); do h=${H[$r]}; ps "$h" "& '$HZ\\win\\stop.ps1' -Match 'cascadia.exe'" | tail -1 | sed "s/^/$h: /" | tee -a "$OUT/orchestrator.log"; done
log "collect from every rank"
for ((r=0; r<N; r++)); do h=${H[$r]}; mkdir -p "$OUT/rank$r-$h"; scp -q "${SSHOPTS[@]}" $(target "$h" | sed 's/-o UserKnownHostsFile=\/dev\/null//') -r "$(target "$h" | awk '{print $NF}'):C:/ecgbench/results/$label/*" "$OUT/rank$r-$h/" 2>&1 | tail -1; done
echo DONE > "$OUT/STATUS"; log "done"
