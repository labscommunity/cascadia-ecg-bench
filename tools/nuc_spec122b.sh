#!/bin/bash
# 122B speculative variants (after the stall diagnosis); EXTRA_FIX env may carry extra worker flags found by the diagnosis
cd "$(dirname "$0")"; source ./hosts.sh
log(){ echo "[$(date +%H:%M:%S)] [spec122b] $*"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
R=/Users/tatef/Workspaces/cascadia-ecg-bench/results
until [ -f ../probe/go_spec122b ]; do sleep 30; done; FIX=$(cat ../probe/go_spec122b); log "go; extra flags=[$FIX]"
stopall(){ for h in alpha beta charlie; do ps $h "& 'C:\ecgbench\harness\win\stop.ps1' -Match 'cascadia.exe' | Select -Last 1" | tail -1 | sed "s/^/$h: /"; done; }
pull_logs(){ local lab=$1; for h in alpha beta charlie; do mkdir -p "$R/$lab/rank-$h"; scp -q "${SSHOPTS[@]}" -i ~/.ssh/id_ed25519 "$(target $h | awk '{print $NF}'):C:/ecgbench/results/$lab/rank*.log" "$R/$lab/rank-$h/" 2>/dev/null; done
  sed 's/\x1b\[[0-9;]*m//g' "$R/$lab/rank-alpha/"rank0*.log 2>/dev/null | grep -E "qwen36 task done" | grep -E "tokens=(25[0-9]|2[0-4][0-9]|1[0-9][0-9])" | tail -2 | sed -E 's/^.*qwen36: //' | cut -c1-500; }
for h in alpha beta; do ps $h "& powershell -NoProfile -ExecutionPolicy Bypass -File C:\cascadia-honyaku\ranks.ps1 stop | Out-Null; '$h honyaku procs=' + (Get-Process cascadia-node-honyaku -ErrorAction SilentlyContinue).Count" | tail -1; done
ps charlie "Get-Process cascadia-node-acrow,ovms -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; 'charlie acrow procs=' + (Get-Process cascadia-node-acrow,ovms -ErrorAction SilentlyContinue).Count" | tail -1
export EXE='C:\ecgbench\rt\spec\cascadia.exe' QUICK=1 REPEATS=2 HEALTH_TIMEOUT=1500
export TREE='C:\ecgbench\shards\q122-sym-3' HOSTS="alpha beta charlie" IPS="192.168.0.101 192.168.0.103 192.168.0.188" MODEL_TAG=q35-122b
run(){ local lab=$1 extra=$2; log "== $lab extra=[$extra $FIX]"
  ENVS="CASCADIA_QWEN36_PROFILE=1;RUST_LOG=info" EXTRA="$extra $FIX" TAGS="config=$lab model=q35-122b stages=3" ./run_chain.sh "$lab" 2>&1 | grep -E "HEALTHY|TIMEOUT|FAILED|did not|^bench (short|medium|long)|rror" | cut -c1-160
  stopall >/dev/null; pull_logs "$lab"; log "$lab: $(cat $R/$lab/STATUS 2>/dev/null)"; }
[ -n "$FIX" ] && run P0f-122b-3nuc-fix-base ""
run P1-122b-3nuc-spec-n3k5 "--prompt-lookup 3 --spec-k 5"
run P2-122b-3nuc-spec-n3k8 "--prompt-lookup 3 --spec-k 8"
run P3-122b-3nuc-spec-n2k4 "--prompt-lookup 2 --spec-k 4"
python3 - <<'PY'
import json,os
R='/Users/tatef/Workspaces/cascadia-ecg-bench/results'
def texts(lab):
    try: return {(r['prompt_id'],i):r.get('text') for i,r in enumerate(json.loads(l) for l in open(f'{R}/{lab}/bench.jsonl')) if r.get('kind')=='bench'}
    except Exception: return {}
base=texts('P0f-122b-3nuc-fix-base') or texts('P0-122b-3nuc-newbin-base')
for lab in ('P1-122b-3nuc-spec-n3k5','P2-122b-3nuc-spec-n3k8','P3-122b-3nuc-spec-n2k4'):
    t=texts(lab); same=sum(1 for k,v in t.items() if base.get(k)==v); print(f'[parity] {lab}: {same}/{len(t)} bench outputs identical to the plain run')
PY
log "spec122b chain done"
