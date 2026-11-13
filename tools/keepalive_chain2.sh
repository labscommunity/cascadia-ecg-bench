#!/bin/bash
# keep-alive variants: K3 = 5 ms + GPU pinned 2500; K4 = 25 ms; K5 = 2 ms; then full protocol + GSM8K-20 on the best (by medium decode); restore
cd "$(dirname "$0")"; source ./hosts.sh
log(){ echo "[$(date +%H:%M:%S)] [ka2] $*"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
R=/Users/tatef/Workspaces/cascadia-ecg-bench/results; PY='C:\ecgbench\venv\Scripts\python.exe'
pin(){ for h in alpha beta charlie; do ps $h "& $PY C:\ecgbench\tmp\zepin.py $1 $2 | Out-Null" >/dev/null; done; }
stopall(){ for h in alpha beta charlie; do ps $h "& 'C:\ecgbench\harness\win\stop.ps1' -Match 'cascadia.exe' | Select -Last 1" | tail -1 | sed "s/^/$h: /"; done; }
pull_logs(){ local lab=$1; for h in alpha beta charlie; do mkdir -p "$R/$lab/rank-$h"; scp -q "${SSHOPTS[@]}" -i ~/.ssh/id_ed25519 "$(target $h | awk '{print $NF}'):C:/ecgbench/results/$lab/rank*.log" "$R/$lab/rank-$h/" 2>/dev/null; done
  sed 's/\x1b\[[0-9;]*m//g' "$R/$lab/rank-charlie/"rank2*.log 2>/dev/null | grep -E "qwen36 profile \(task\)" | grep -E "steps=2[0-9][0-9]" | tail -1 | sed -E 's/^.*qwen36: //' | cut -c1-300; }
medium_dec(){ python3 -c "
import json,statistics as st
r=[json.loads(l) for l in open('$R/$1/bench.jsonl')]; v=[x['decode_tok_s'] for x in r if x.get('kind')=='bench' and x.get('prompt_id')=='medium' and x.get('decode_tok_s')]; print(round(st.median(v),2) if v else 0)" 2>/dev/null; }
export EXE='C:\ecgbench\rt\spec\cascadia.exe' HEALTH_TIMEOUT=1500 TREE='C:\ecgbench\shards\q122-sym-3' HOSTS="alpha beta charlie" IPS="192.168.0.101 192.168.0.103 192.168.0.188" MODEL_TAG=q35-122b
quick(){ local lab=$1 ka=$2; log "== $lab keepalive=${ka}ms"; QUICK=1 REPEATS=2 ENVS="CASCADIA_QWEN36_PROFILE=1;RUST_LOG=info;CASCADIA_QWEN36_GPU_KEEPALIVE_MS=$ka" TAGS="config=$lab model=q35-122b stages=3" ./run_chain.sh "$lab" 2>&1 | grep -E "HEALTHY|TIMEOUT|FAILED|did not|^bench (short|medium|long)|rror" | cut -c1-160; stopall >/dev/null; pull_logs "$lab"; log "$lab: $(cat $R/$lab/STATUS 2>/dev/null) medium=$(medium_dec $lab)"; }
pin 2500 2500; quick K3-122b-3nuc-keepalive5-pin2500 5; pin 100 2500
quick K4-122b-3nuc-keepalive25 25
quick K5-122b-3nuc-keepalive2 2
best=K1-122b-3nuc-keepalive5; bestv=$(medium_dec K1-122b-3nuc-keepalive5); bestka=5; bestpin=0
for c in "K3-122b-3nuc-keepalive5-pin2500 5 1" "K4-122b-3nuc-keepalive25 25 0" "K5-122b-3nuc-keepalive2 2 0"; do set -- $c; v=$(medium_dec $1); if python3 -c "import sys; sys.exit(0 if float('$v')>float('$bestv') else 1)"; then best=$1; bestv=$v; bestka=$2; bestpin=$3; fi; done
log "best quick config: $best medium=$bestv keepalive=$bestka pin=$bestpin"
[ "$bestpin" = 1 ] && pin 2500 2500
log "== D3k full protocol + GSM8K-20 with keepalive=${bestka}ms pin=$bestpin"; unset QUICK; REPEATS=3 ENVS="CASCADIA_QWEN36_PROFILE=1;RUST_LOG=info;CASCADIA_QWEN36_GPU_KEEPALIVE_MS=$bestka" EVAL_TOKENS=400 EVAL_N=20 EVAL_WAIT_MIN=90 TAGS="config=D3k-122b-3shard-3nuc-keepalive$bestka model=q35-122b stages=3" ./run_chain.sh D3k-122b-3stage-3nuc-keepalive 2>&1 | grep -E "HEALTHY|TIMEOUT|FAILED|did not|^bench (short|medium|long)|eval|rror" | cut -c1-160; stopall >/dev/null; pull_logs D3k-122b-3stage-3nuc-keepalive; log "D3k: $(cat $R/D3k-122b-3stage-3nuc-keepalive/STATUS 2>/dev/null) medium=$(medium_dec D3k-122b-3stage-3nuc-keepalive) (keepalive=$bestka pin=$bestpin)"
pin 100 2500
log "restoring NUC services"; ./restore_nucs.sh > ../probe/restore_ka.out 2>&1; grep -E "HONYAKU|ACROW" ../probe/restore_ka.out | tail -2
log "keepalive chain 2 done"
