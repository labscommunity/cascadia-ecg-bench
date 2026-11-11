#!/bin/bash
# GSM8K-N eval against a running server on <host>. usage: [N=40] [API=:8130] TAGS="model=q36-35b config=A1" run_eval.sh <host> <label>
set -u; cd "$(dirname "$0")"; source ./hosts.sh
h=$1; label=$2; API=${API:-:8130}; N=${N:-40}; R="C:\\ecgbench\\results\\$label"; HZ='C:\ecgbench\harness'; PY='C:\ecgbench\venv\Scripts\python.exe'
TAGARGS=""; for t in ${TAGS:-config=$label}; do TAGARGS="$TAGARGS --tag $t"; done
OUT="/Users/tatef/Workspaces/cascadia-ecg-bench/results/$label"; mkdir -p "$OUT"
ps() { local f; f=$(mktemp); printf '%s\n' "$1" > "$f"; ./wps.sh "$h" "$f"; rm -f "$f"; }
ps "New-Item -ItemType Directory -Force -Path '$R' | Out-Null; 'ok'" >/dev/null
echo "[$(date +%H:%M:%S)] eval start on $h ($label, n=$N)" | tee -a "$OUT/orchestrator.log"
# detached so a long eval survives; poll for the summary line
ps "& '$HZ\\win\\launch.ps1' -Cmd '\"$PY\" $HZ\\eval_gsm8k.py --base http://127.0.0.1:${API##*:} --n $N --max-tokens ${EVAL_TOKENS:-512} --out $R\\gsm8k.jsonl $TAGARGS' -Log '$R\\eval-client.log' -Priority Normal" | tail -1
for i in $(seq 1 ${EVAL_WAIT_MIN:-120}); do sleep 60; r=$(ps "if (Test-Path '$R\\gsm8k.jsonl') { Select-String -Path '$R\\gsm8k.jsonl' -Pattern '\"kind\": \"summary\"' | Select -Last 1 | % { \$_.Line } }; (Get-Content '$R\\gsm8k.jsonl' -ErrorAction SilentlyContinue | Measure-Object -Line).Lines"); echo "$r" | grep -q summary && break; echo "[$(date +%H:%M:%S)] eval progress: $(echo "$r" | tail -1) answers"; done
echo "$r" | grep summary | tee -a "$OUT/orchestrator.log"
scp -q "${SSHOPTS[@]}" $(target "$h" | sed 's/-o UserKnownHostsFile=\/dev\/null//') "$(target "$h" | awk '{print $NF}'):C:/ecgbench/results/$label/gsm8k.jsonl" "$OUT/" 2>&1 | tail -1
echo "[$(date +%H:%M:%S)] eval done" | tee -a "$OUT/orchestrator.log"
