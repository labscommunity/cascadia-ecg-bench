#!/bin/bash
# Concurrency sweep on a whole-model ov-genai server with continuous batching (--cb). usage: CONC="1 2 4" run_conc.sh <host> <label>
set -u; cd "$(dirname "$0")"; source ./hosts.sh
h=$1; label=$2; R="C:\\ecgbench\\results\\$label"; HZ='C:\ecgbench\harness'; PY='C:\ecgbench\venv\Scripts\python.exe'
OUT="/Users/tatef/Workspaces/cascadia-ecg-bench/results/$label"; mkdir -p "$OUT"
ps() { local f; f=$(mktemp); printf '%s\n' "$1" > "$f"; ./wps.sh "$h" "$f"; rm -f "$f"; }
log() { echo "[$(date +%H:%M:%S)] [$h/$label] $*" | tee -a "$OUT/orchestrator.log"; }
ps "New-Item -ItemType Directory -Force -Path '$R' | Out-Null; 'ok'" >/dev/null
log "launch --cb server"; ps "& '$HZ\\win\\server.ps1' -Mode worker -Model '$MODEL' -Engine ov-genai -Device GPU -Rank 0 -Total 1 -Api ':8130' -Extra '--cb ${CB_EXTRA:-}' -Log '$R\\server.log'" | grep -E "CMD|LAUNCH" | tee -a "$OUT/orchestrator.log"
hres=$(ps "& '$HZ\\win\\health.ps1' -Base http://127.0.0.1:8130 -TimeoutSec ${HEALTH_TIMEOUT:-900}"); log "$hres"
echo "$hres" | grep -q HEALTHY || { ps "Get-Content '$R\\server.log' -Tail 30" | tee -a "$OUT/orchestrator.log"; ps "& '$HZ\\win\\stop.ps1' -Match 'cascadia.exe'" >/dev/null; echo FAILED > "$OUT/STATUS"; exit 1; }
ps "& '$PY' $HZ\\bench_client.py --base http://127.0.0.1:8130 --mode bench --set perf --repeats 1 --warmup 1 --out '$R\\c1-single.jsonl' --tag config=$label --tag conc=1" | python3 -c "
import sys,json; sys.stdin.reconfigure(errors='replace')
for l in sys.stdin:
    try: r=json.loads(l)
    except Exception: continue
    print(r.get('kind'), r.get('prompt_id'), 'ttft', r.get('ttft_s'), 'dec', r.get('decode_tok_s'), 'ct', r.get('completion_tokens'))" | tee -a "$OUT/orchestrator.log"
for c in ${CONC:-2 4 8}; do
  log "concurrency $c"
  ps "& '$HZ\\win\\launch.ps1' -Cmd 'powershell -NoProfile -ExecutionPolicy Bypass -File $HZ\\win\\sample.ps1 -Out $R\\conc$c.util.jsonl -Seconds 240' -Log '$R\\sampler-c$c.log' -Priority Normal" >/dev/null
  ps "& '$PY' $HZ\\bench_client.py --base http://127.0.0.1:8130 --mode bench --set perf --repeats 2 --warmup 0 --concurrency $c --out '$R\\conc$c.jsonl' --tag config=$label --tag conc=$c" | python3 -c "
import sys,json; sys.stdin.reconfigure(errors='replace')
for l in sys.stdin:
    try: r=json.loads(l)
    except Exception: continue
    if r.get('kind')=='aggregate': print('AGG conc', r.get('concurrency'), 'req', r.get('requests'), 'tokens', r.get('total_completion_tokens'), 'wall', r.get('wall_s'), 'agg tok/s', r.get('aggregate_tok_s'), 'errors', r.get('errors'))" | tee -a "$OUT/orchestrator.log"
  ps "& '$HZ\\win\\stop.ps1' -Match 'powershell' -CmdLike '*sample.ps1*conc$c*'" >/dev/null
done
ps "& '$HZ\\win\\stop.ps1' -Match 'cascadia.exe'" | tail -1 | tee -a "$OUT/orchestrator.log"
scp -q "${SSHOPTS[@]}" $(target "$h" | sed 's/-o UserKnownHostsFile=\/dev\/null//') -r "$(target "$h" | awk '{print $NF}'):C:/ecgbench/results/$label/*" "$OUT/" 2>&1 | tail -1
echo DONE > "$OUT/STATUS"; log done
