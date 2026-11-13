#!/bin/bash
# Orchestrate one benchmark configuration on one Windows box.
# usage: MODEL=... ENGINE=ov-genai DEVICE=GPU [EXTRA="--cb"] [NOLAUNCH=1] [NOSTOP=1] [API=:8130] [TAGS="config=x"] run_config.sh <host> <label>
set -u
cd "$(dirname "$0")"; source ./hosts.sh
h=$1; label=$2; API=${API:-:8130}; PORT=${API##*:}; BASE="http://127.0.0.1:$PORT"
R="C:\\ecgbench\\results\\$label"; RF="C:/ecgbench/results/$label"
PY='C:\ecgbench\venv\Scripts\python.exe'; HZ='C:\ecgbench\harness'
TAGS=${TAGS:-config=$label}; TAGARGS=""; for t in $TAGS; do TAGARGS="$TAGARGS --tag $t"; done
OUT="/Users/tatef/Workspaces/cascadia-ecg-bench/results/$label"; mkdir -p "$OUT"
ps() { local f; f=$(mktemp); printf '%s\n' "$1" > "$f"; ./wps.sh "$h" "$f"; rm -f "$f"; }
log() { echo "[$(date +%H:%M:%S)] [$h/$label] $*" | tee -a "$OUT/orchestrator.log"; }
ps "New-Item -ItemType Directory -Force -Path '$R' | Out-Null; 'ok'" >/dev/null
if [ -z "${NOLAUNCH:-}" ]; then
  log "launch server: $MODEL engine=$ENGINE device=$DEVICE api=$API extra=${EXTRA:-}"
  EX=""; [ -n "${EXTRA:-}" ] && EX="-Extra '$EXTRA'"
  ps "& '$HZ\\win\\server.ps1' ${EXE:+-Exe '$EXE'} ${ENVS:+-Env '$ENVS'} -Mode run -Model '$MODEL' -Engine $ENGINE -Device '$DEVICE' -Api '$API' $EX -Log '$R\\server.log'" | tee -a "$OUT/orchestrator.log"
fi
log "waiting for health"
hres=$(ps "& '$HZ\\win\\health.ps1' -Base $BASE -TimeoutSec ${HEALTH_TIMEOUT:-1500}")
log "$hres"
if ! echo "$hres" | grep -q HEALTHY; then
  log "server did not become healthy; tail of server.log:"; ps "Get-Content '$R\\server.log' -Tail 40" | tee -a "$OUT/orchestrator.log"
  ps "Get-Content '$R\\server.log'" > "$OUT/server.log" 2>/dev/null
  [ -z "${NOSTOP:-}" ] && ps "& '$HZ\\win\\stop.ps1' -Match 'cascadia.exe'" | tee -a "$OUT/orchestrator.log"
  echo "FAILED" > "$OUT/STATUS"; exit 1
fi
log "calib"; ps "& '$PY' $HZ\\bench_client.py ${CLIENT_EXTRA:-} --base $BASE --mode calib --set all --out '$R\\calib.jsonl' $TAGARGS" | tail -3 | cut -c1-200 | tee -a "$OUT/orchestrator.log"
if [ -z "${QUICK:-}" ]; then
log "idle baseline (30 s)"
ps "& '$HZ\\win\\launch.ps1' -Cmd 'powershell -NoProfile -ExecutionPolicy Bypass -File $HZ\\win\\sample.ps1 -Out $R\\idle.util.jsonl -Seconds 32' -Log '$R\\sampler-idle.log' -Priority Normal" >/dev/null
ps "& '$HZ\\win\\socwatch_run.ps1' -Seconds 30 -Prefix '$R\\idle.sw'" | tail -1 | cut -c1-300 | tee -a "$OUT/orchestrator.log"
fi
log "bench perf (warmup 1, repeats ${REPEATS:-3})"
ps "& '$HZ\\win\\launch.ps1' -Cmd 'powershell -NoProfile -ExecutionPolicy Bypass -File $HZ\\win\\sample.ps1 -Out $R\\bench.util.jsonl -Seconds ${BENCH_SAMPLE_SECS:-900}' -Log '$R\\sampler-bench.log' -Priority Normal" >/dev/null
ps "& '$PY' $HZ\\bench_client.py ${CLIENT_EXTRA:-} --base $BASE --mode bench --set perf --repeats ${REPEATS:-3} --warmup 1 --stream-diag --out '$R\\bench.jsonl' $TAGARGS" | python3 -c "
import sys,json
sys.stdin.reconfigure(errors='replace')
for l in sys.stdin:
    try: r=json.loads(l)
    except Exception: print(l.strip()[:200]); continue
    print(r.get('kind'), r.get('prompt_id'), 'ttft', r.get('ttft_s'), 'dec', r.get('decode_tok_s'), 'tok', r.get('completion_tokens'), 'status', r.get('status'), (r.get('error') or '')[:80])" | tee -a "$OUT/orchestrator.log"
if [ -z "${QUICK:-}" ]; then
log "parity set"
ps "& '$PY' $HZ\\bench_client.py ${CLIENT_EXTRA:-} --base $BASE --mode bench --set parity --repeats 1 --warmup 0 --max-tokens ${PARITY_TOKENS:-160} --out '$R\\parity.jsonl' $TAGARGS" | python3 -c "
import sys,json
sys.stdin.reconfigure(errors='replace')
for l in sys.stdin:
    try: r=json.loads(l)
    except Exception: print(l.strip()[:200]); continue
    print(r.get('kind'), r.get('prompt_id'), 'ttft', r.get('ttft_s'), 'dec', r.get('decode_tok_s'), 'tok', r.get('completion_tokens'), 'status', r.get('status'))" | tee -a "$OUT/orchestrator.log"
ps "& '$HZ\\win\\stop.ps1' -Match 'powershell' -CmdLike '*sample.ps1*bench.util*'" >/dev/null
log "steady-state power (90 s loop, 60 s SoC Watch)"
ps "& '$HZ\\win\\launch.ps1' -Cmd 'powershell -NoProfile -ExecutionPolicy Bypass -File $HZ\\win\\sample.ps1 -Out $R\\steady.util.jsonl -Seconds 95' -Log '$R\\sampler-steady.log' -Priority Normal" >/dev/null
ps "& '$HZ\\win\\launch.ps1' -Cmd '\"$PY\" $HZ\\bench_client.py ${CLIENT_EXTRA:-} --base $BASE --mode steady --seconds 90 --steady-prompt medium --max-tokens 256 --concurrency ${STEADY_CONC:-1} --out $R\\steady.jsonl $TAGARGS' -Log '$R\\steady-client.log' -Priority Normal" >/dev/null
sleep 12
ps "& '$HZ\\win\\socwatch_run.ps1' -Seconds 60 -Prefix '$R\\steady.sw'" | tail -1 | cut -c1-300 | tee -a "$OUT/orchestrator.log"
sleep 25
fi
if [ -z "${NOSTOP:-}" ]; then log "stop server"; ps "& '$HZ\\win\\stop.ps1' -Match 'cascadia.exe'" | tail -1 | tee -a "$OUT/orchestrator.log"; fi
log "collect results"
scp -q "${SSHOPTS[@]}" $(target "$h" | sed 's/-o UserKnownHostsFile=\/dev\/null//') -r "$(target "$h" | awk '{print $NF}'):$RF/*" "$OUT/" 2>&1 | tail -1
echo "DONE" > "$OUT/STATUS"; log "done"; ls "$OUT"
