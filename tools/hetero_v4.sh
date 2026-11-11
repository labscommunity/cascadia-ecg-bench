#!/bin/bash
cd "$(dirname "$0")"; source ./hosts.sh
log(){ echo "[$(date +%H:%M:%S)] [mixed] $*"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
log "HETERO retry 3 on charlie (device quoted for PowerShell)"
QUICK=1 REPEATS=1 HEALTH_TIMEOUT=1500 MODEL='C:\ecgbench\models\Qwen3.6-35B-A3B-int4-ov' ENGINE=ov-genai DEVICE='HETERO:GPU,CPU' TAGS="config=E-35b-hetero host=charlie model=q36-35b device=HETERO" ./run_config.sh charlie E-charlie-35b-hetero3 2>&1 | grep -E "HEALTHY|TIMEOUT|FAILED|did not|^bench|^warmup|rc=|rror" | cut -c1-200
log "hetero done: $(cat /Users/tatef/Workspaces/cascadia-ecg-bench/results/E-charlie-35b-hetero3/STATUS 2>/dev/null)"
ps alpha "Remove-Item -Recurse -Force C:\ecgbench\shards\q36-2stage -ErrorAction SilentlyContinue; 'alpha free=' + [math]::Round((Get-PSDrive C).Free/1GB,1)" | tail -1
ps charlie "Remove-Item -Recurse -Force C:\ecgbench\models\Qwen3.6-35B-A3B-int4-ov, C:\ecgbench\results\dl35b.done -ErrorAction SilentlyContinue; 'charlie free=' + [math]::Round((Get-PSDrive C).Free/1GB,1)" | tail -1
echo "[$(date +%H:%M:%S)] [alpha-followup] alpha follow-up done" >> ../probe/alpha_b4.out
log "released D3"
