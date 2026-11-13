#!/bin/bash
# GPU clock / queue-throttle experiments on the all-local 122B (3 NUCs) + direct stage profiles + whole 35B on beta pinned vs not
cd "$(dirname "$0")"; source ./hosts.sh
log(){ echo "[$(date +%H:%M:%S)] [clk] $*"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
PY='C:\ecgbench\venv\Scripts\python.exe'; R=/Users/tatef/Workspaces/cascadia-ecg-bench/results
pin(){ for h in alpha beta charlie; do ps $h "& $PY C:\ecgbench\tmp\zepin.py $1 $2 2>&1 | Select-String after" | tail -1 | sed "s/^/$h: /"; done; }
stopall(){ for h in alpha beta charlie; do ps $h "& 'C:\ecgbench\harness\win\stop.ps1' -Match 'cascadia.exe' | Select -Last 1" | tail -1 | sed "s/^/$h: /"; done; }
# 0. quiet the boxes
for h in alpha beta; do ps $h "foreach (\$t in @('honyaku-watchdog','cascadia-watchdog')) { Disable-ScheduledTask -TaskName \$t -ErrorAction SilentlyContinue | Out-Null }; & powershell -NoProfile -ExecutionPolicy Bypass -File C:\cascadia-honyaku\ranks.ps1 stop | Out-Null; Start-Sleep 2; '$h honyaku procs=' + (Get-Process cascadia-node-honyaku -ErrorAction SilentlyContinue).Count" | tail -1; done
ps charlie "Stop-ScheduledTask -TaskName cascadia-acrow-node -ErrorAction SilentlyContinue; Get-Process cascadia-node-acrow,ovms -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep 2; 'charlie acrow procs=' + (Get-Process cascadia-node-acrow,ovms -ErrorAction SilentlyContinue).Count" | tail -1
rm -f /tmp/restore_nucs.done
for h in alpha beta charlie; do ps $h "'$h manifest=' + (Get-FileHash C:\ecgbench\shards\q122-sym-3\manifest.json).Hash.Substring(0,16) + ' ' + ((Get-ChildItem C:\ecgbench\shards\q122-sym-3 -Directory | % { \$_.Name + '=' + (Get-Item (\$_.FullName + '\stage.bin')).Length }) -join ' ')" | tail -1; done
export QUICK=1 REPEATS=2 HEALTH_TIMEOUT=1500
# 1. G1: GPU pinned at 2500 MHz on all ranks
log "G1: pin 2500"; pin 2500 2500
( sleep 300; ps alpha "& $PY C:\ecgbench\tmp\zefreq.py 60 0.5 2>&1 | Select-String domain0" | tail -1 | sed 's/^/[freq alpha during G1] /' ) &
TREE='C:\ecgbench\shards\q122-sym-3' HOSTS="alpha beta charlie" IPS="192.168.0.101 192.168.0.103 192.168.0.188" MODEL_TAG=q35-122b TAGS="config=G1-122b-3nuc-pin2500 model=q35-122b stages=3" ./run_chain.sh G1-122b-3nuc-pin2500 2>&1 | grep -E "HEALTHY|TIMEOUT|FAILED|^bench|rror" | cut -c1-160
wait; stopall; log "G1 done: $(cat $R/G1-122b-3nuc-pin2500/STATUS 2>/dev/null)"
# 2. G2: unpinned, OpenVINO queue throttle/priority HIGH
log "G2: unpin + GPU_QUEUE_THROTTLE=HIGH"; pin 100 2500
( sleep 300; ps alpha "& $PY C:\ecgbench\tmp\zefreq.py 60 0.5 2>&1 | Select-String domain0" | tail -1 | sed 's/^/[freq alpha during G2] /' ) &
EXTRA="--ov-config GPU_QUEUE_THROTTLE=HIGH --ov-config GPU_QUEUE_PRIORITY=HIGH" TREE='C:\ecgbench\shards\q122-sym-3' HOSTS="alpha beta charlie" IPS="192.168.0.101 192.168.0.103 192.168.0.188" MODEL_TAG=q35-122b TAGS="config=G2-122b-3nuc-throttle-high model=q35-122b stages=3" ./run_chain.sh G2-122b-3nuc-throttle-high 2>&1 | grep -E "HEALTHY|TIMEOUT|FAILED|^bench|rror" | cut -c1-160
wait; stopall; log "G2 done: $(cat $R/G2-122b-3nuc-throttle-high/STATUS 2>/dev/null)"
# 3. baseline frequency sample (unpinned, no throttle) from D3b is known; now direct stage profiles (GPU idle), unpinned then pinned
for cfg in "" "pin"; do
  [ "$cfg" = pin ] && pin 2500 2500
  for h in alpha beta charlie; do st=$([ $h = alpha ] && echo stage0 || { [ $h = beta ] && echo stage1 || echo stage2; }); log "profile $h $st ${cfg:-unpinned}"; ps $h "& $PY C:\ecgbench\tmp\stage_profile.py C:\ecgbench\shards\q122-sym-3\\$st 4096 GPU 2>&1" | grep -v "^Warning" | sed "s/^/[$h $st ${cfg:-unpinned}] /" | cut -c1-200; done
done
log "profile with throttle HIGH (pinned)"; ps charlie "& $PY C:\ecgbench\tmp\stage_profile.py C:\ecgbench\shards\q122-sym-3\stage2 4096 GPU GPU_QUEUE_THROTTLE=HIGH GPU_QUEUE_PRIORITY=HIGH 2>&1" | grep -v "^Warning" | sed "s/^/[charlie stage2 pin+throttle] /" | cut -c1-200
pin 100 2500
# 4. whole 35B on beta: pinned vs unpinned (quick)
for cfg in pin unpin; do
  [ "$cfg" = pin ] && pin 2500 2500 || pin 100 2500
  MODEL='C:\ecgbench\models\Qwen3.6-35B-A3B-int4-ov' ENGINE=ov-genai DEVICE=GPU TAGS="config=B6-whole-32gb-gpu-$cfg host=beta model=q36-35b" ./run_config.sh beta B6-beta-whole-gpu-$cfg 2>&1 | grep -E "HEALTHY|TIMEOUT|FAILED|^bench medium|rror" | cut -c1-160
  log "B6 $cfg done: $(cat $R/B6-beta-whole-gpu-$cfg/STATUS 2>/dev/null)"
done
pin 100 2500
log "restoring services"; ./restore_nucs.sh > ../probe/restore_clk.out 2>&1; grep -E "HONYAKU|ACROW" ../probe/restore_clk.out | tail -2
log "clocks chain done"
