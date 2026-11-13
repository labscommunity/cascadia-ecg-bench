#!/bin/bash
# 122B all-local 3-NUC pipeline with the ecg/spec-decode build: profiled baseline, n-gram speculative variants, parity, GSM8K-20
cd "$(dirname "$0")"; source ./hosts.sh
log(){ echo "[$(date +%H:%M:%S)] [spec122] $*"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
R=/Users/tatef/Workspaces/cascadia-ecg-bench/results
stopall(){ for h in alpha beta charlie; do ps $h "& 'C:\ecgbench\harness\win\stop.ps1' -Match 'cascadia.exe' | Select -Last 1" | tail -1 | sed "s/^/$h: /"; done; }
pull_logs(){ local lab=$1; for h in alpha beta charlie; do mkdir -p "$R/$lab/rank-$h"; scp -q "${SSHOPTS[@]}" -i ~/.ssh/id_ed25519 "$(target $h | awk '{print $NF}'):C:/ecgbench/results/$lab/rank*.log" "$R/$lab/rank-$h/" 2>/dev/null; done
  grep -hE "qwen36 task done|qwen36 profile \(task\)|qwen36 ov profile|spec step" "$R/$lab/rank-alpha/"rank0*.log 2>/dev/null | tail -6 | cut -c1-400 | sed 's/\x1b\[[0-9;]*m//g'; }
for h in alpha beta; do ps $h "foreach (\$t in @('honyaku-watchdog','cascadia-watchdog')) { Disable-ScheduledTask -TaskName \$t -ErrorAction SilentlyContinue | Out-Null }; & powershell -NoProfile -ExecutionPolicy Bypass -File C:\cascadia-honyaku\ranks.ps1 stop | Out-Null; Start-Sleep 2; '$h honyaku procs=' + (Get-Process cascadia-node-honyaku -ErrorAction SilentlyContinue).Count" | tail -1; done
ps charlie "Stop-ScheduledTask -TaskName cascadia-acrow-node -ErrorAction SilentlyContinue; Get-Process cascadia-node-acrow,ovms -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep 2; 'charlie acrow procs=' + (Get-Process cascadia-node-acrow,ovms -ErrorAction SilentlyContinue).Count" | tail -1
rm -f /tmp/restore_nucs.done
export EXE='C:\ecgbench\rt\spec\cascadia.exe' QUICK=1 REPEATS=2 HEALTH_TIMEOUT=1500
export TREE='C:\ecgbench\shards\q122-sym-3' HOSTS="alpha beta charlie" IPS="192.168.0.101 192.168.0.103 192.168.0.188" MODEL_TAG=q35-122b
run(){ local lab=$1 extra=$2 envs=$3; log "== $lab extra=[$extra] env=[$envs]"
  ENVS="$envs" EXTRA="$extra" TAGS="config=$lab model=q35-122b stages=3" ./run_chain.sh "$lab" 2>&1 | grep -E "HEALTHY|TIMEOUT|FAILED|did not|^bench (short|medium|long)|rror" | cut -c1-160
  stopall >/dev/null; pull_logs "$lab"; log "$lab: $(cat $R/$lab/STATUS 2>/dev/null)"; }
run P0-122b-3nuc-newbin-base "" "CASCADIA_QWEN36_PROFILE=1;RUST_LOG=info"
run P0p-122b-3nuc-newbin-perfcount "--ov-config PERF_COUNT=YES" "CASCADIA_QWEN36_PROFILE=1;RUST_LOG=info"
run P1-122b-3nuc-spec-n3k5 "--prompt-lookup 3 --spec-k 5" "CASCADIA_QWEN36_PROFILE=1;RUST_LOG=info"
run P2-122b-3nuc-spec-n3k8 "--prompt-lookup 3 --spec-k 8" "CASCADIA_QWEN36_PROFILE=1;RUST_LOG=info"
run P3-122b-3nuc-spec-n2k4 "--prompt-lookup 2 --spec-k 4" "CASCADIA_QWEN36_PROFILE=1;RUST_LOG=info"
# parity: speculative output must equal the plain output (greedy, lossless by construction)
python3 - <<'PY'
import json,os
R='/Users/tatef/Workspaces/cascadia-ecg-bench/results'
def texts(lab):
    try: return {(r['prompt_id'],i):r.get('text') for i,r in enumerate(json.loads(l) for l in open(f'{R}/{lab}/bench.jsonl')) if r.get('kind')=='bench'}
    except Exception as e: return {}
base=texts('P0-122b-3nuc-newbin-base')
for lab in ('P1-122b-3nuc-spec-n3k5','P2-122b-3nuc-spec-n3k8','P3-122b-3nuc-spec-n2k4'):
    t=texts(lab); same=sum(1 for k,v in t.items() if base.get(k)==v); print(f'[parity] {lab}: {same}/{len(t)} bench outputs identical to the plain run')
PY
log "spec122 chain done (eval + restore handled by the next chain)"
