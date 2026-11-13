#!/bin/bash
# after the keep-alive commit lands: rebuild on tate-07, redeploy to the NUCs, measure the 122B pipeline with keep-alive on (quick + full + GSM8K-20), then restore everything
cd "$(dirname "$0")"; source ./hosts.sh
log(){ echo "[$(date +%H:%M:%S)] [ka] $*"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
R=/Users/tatef/Workspaces/cascadia-ecg-bench/results; S=(-o ConnectTimeout=20 -o BatchMode=yes -o LogLevel=ERROR -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null)
until [ -f ../probe/go_keepalive ]; do sleep 30; done
until grep -q "spec122b chain done" ../probe/spec122c.out 2>/dev/null; do sleep 30; done; log "P1 finished; building keep-alive runtime"
( cd ~/Workspaces/tahoma-worktrees/ecg-spec && git bundle create /tmp/cascadia-spec3.bundle v0.2.7..ecg/spec-decode >/dev/null 2>&1 ); scp -q "${S[@]}" -i ~/.ssh/id_ed25519 /tmp/cascadia-spec3.bundle cascadia-tate-07-ts:C:/ecgbench/cascadia-spec3.bundle
ps tate07 "Set-Location C:\ecgbench\src\cascadia; git fetch -q C:\ecgbench\cascadia-spec3.bundle 'refs/heads/ecg/spec-decode:refs/remotes/bundle4/ecg/spec-decode' 2>&1 | Select -Last 1; git checkout -q -B ecg/spec-decode bundle4/ecg/spec-decode 2>&1 | Select -Last 1; 'HEAD=' + (git rev-parse --short HEAD) + ' ' + (git log -1 --format=%s); Remove-Item C:\ecgbench\results\build1.done -ErrorAction SilentlyContinue" | tail -1
./wbg.sh tate07 'C:\ecgbench\results\build3.log' 'C:\ecgbench\build1.cmd' | tail -1
t0=$(date +%s); until ps tate07 "Test-Path C:\ecgbench\results\build1.done" | tail -1 | grep -q True; do sleep 30; [ $(( $(date +%s)-t0 )) -gt 1500 ] && { log "BUILD TIMEOUT: $(ps tate07 "Get-Content C:\ecgbench\results\build3.log | Select-String '^error' -Context 0,3 | Select -First 1" | tr '\n' ' ' | cut -c1-300)"; exit 1; }; done
log "build ok: $(ps tate07 "Get-Content C:\ecgbench\results\build3.log -Tail 1" | tail -1 | cut -c1-100)"
ps tate07 "Copy-Item C:\ecgbench\src\cascadia\target\x86_64-pc-windows-msvc\release\cascadia.exe C:\ecgbench\rt\spec\cascadia.exe -Force; Compress-Archive -Path C:\ecgbench\rt\spec\cascadia.exe -DestinationPath C:\ecgbench\cascadia-ka.zip -Force; 'zip MB=' + [math]::Round((Get-Item C:\ecgbench\cascadia-ka.zip).Length/1MB,1)" | tail -1
scp -q "${S[@]}" -i ~/.ssh/id_ed25519 cascadia-tate-07-ts:C:/ecgbench/cascadia-ka.zip /tmp/cascadia-ka.zip
for h in alpha beta charlie; do ip=$(target $h | awk '{print $NF}'); scp -q "${S[@]}" -i ~/.ssh/id_ed25519 /tmp/cascadia-ka.zip "$ip:C:/ecgbench/cascadia-ka.zip"; ps $h "Expand-Archive -Path C:\ecgbench\cascadia-ka.zip -DestinationPath C:\ecgbench\rt\spec -Force | Out-Null; '$h exe ' + (Get-Item C:\ecgbench\rt\spec\cascadia.exe).LastWriteTime" | tail -1; done
for h in alpha beta; do ps $h "& powershell -NoProfile -ExecutionPolicy Bypass -File C:\cascadia-honyaku\ranks.ps1 stop | Out-Null; '$h honyaku procs=' + (Get-Process cascadia-node-honyaku -ErrorAction SilentlyContinue).Count" | tail -1; done
ps charlie "Get-Process cascadia-node-acrow,ovms -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; 'charlie acrow procs=' + (Get-Process cascadia-node-acrow,ovms -ErrorAction SilentlyContinue).Count" | tail -1
rm -f /tmp/restore_nucs.done
export EXE='C:\ecgbench\rt\spec\cascadia.exe' HEALTH_TIMEOUT=1500 TREE='C:\ecgbench\shards\q122-sym-3' HOSTS="alpha beta charlie" IPS="192.168.0.101 192.168.0.103 192.168.0.188" MODEL_TAG=q35-122b
stopall(){ for h in alpha beta charlie; do ps $h "& 'C:\ecgbench\harness\win\stop.ps1' -Match 'cascadia.exe' | Select -Last 1" | tail -1 | sed "s/^/$h: /"; done; }
pull_logs(){ local lab=$1; for h in alpha beta charlie; do mkdir -p "$R/$lab/rank-$h"; scp -q "${SSHOPTS[@]}" -i ~/.ssh/id_ed25519 "$(target $h | awk '{print $NF}'):C:/ecgbench/results/$lab/rank*.log" "$R/$lab/rank-$h/" 2>/dev/null; done
  sed 's/\x1b\[[0-9;]*m//g' "$R/$lab/rank-charlie/"rank2*.log 2>/dev/null | grep -E "qwen36 profile \(task\)" | grep -E "steps=2[0-9][0-9]" | tail -1 | sed -E 's/^.*qwen36: //' | cut -c1-400
  sed 's/\x1b\[[0-9;]*m//g' "$R/$lab/rank-alpha/"rank0*.log 2>/dev/null | grep -E "qwen36 task done" | grep -E "tokens=2[0-9][0-9]" | tail -1 | sed -E 's/^.*qwen36: //' | cut -c1-300; }
# K1: quick, keep-alive 5 ms
log "== K1 quick keep-alive 5ms"; QUICK=1 REPEATS=2 ENVS="CASCADIA_QWEN36_PROFILE=1;RUST_LOG=info;CASCADIA_QWEN36_GPU_KEEPALIVE_MS=5" TAGS="config=K1-122b-3nuc-keepalive5 model=q35-122b stages=3" ./run_chain.sh K1-122b-3nuc-keepalive5 2>&1 | grep -E "HEALTHY|TIMEOUT|FAILED|did not|^bench (short|medium|long)|rror" | cut -c1-160; stopall >/dev/null; pull_logs K1-122b-3nuc-keepalive5; log "K1: $(cat $R/K1-122b-3nuc-keepalive5/STATUS 2>/dev/null)"
# K2: full protocol (3 repeats, steady, chain-wide power) + GSM8K-20 with keep-alive
log "== K2 full keep-alive 5ms + GSM8K-20"; unset QUICK; REPEATS=3 ENVS="CASCADIA_QWEN36_PROFILE=1;RUST_LOG=info;CASCADIA_QWEN36_GPU_KEEPALIVE_MS=5" EVAL_TOKENS=400 EVAL_N=20 EVAL_WAIT_MIN=90 TAGS="config=D3k-122b-3shard-3nuc-keepalive model=q35-122b stages=3" ./run_chain.sh D3k-122b-3stage-3nuc-keepalive 2>&1 | grep -E "HEALTHY|TIMEOUT|FAILED|did not|^bench (short|medium|long)|eval|rror" | cut -c1-160; stopall >/dev/null; pull_logs D3k-122b-3stage-3nuc-keepalive; log "D3k: $(cat $R/D3k-122b-3stage-3nuc-keepalive/STATUS 2>/dev/null)"
log "restoring NUC services"; ./restore_nucs.sh > ../probe/restore_ka.out 2>&1; grep -E "HONYAKU|ACROW" ../probe/restore_ka.out | tail -2
log "keepalive chain done"
