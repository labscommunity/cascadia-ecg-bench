#!/bin/bash
# idle-gap experiment: does a stage stall when the GPU idles ~70 ms between steps (as in the 3-rank pipeline)? plus GPU frequency during it
cd "$(dirname "$0")"; source ./hosts.sh
log(){ echo "[$(date +%H:%M:%S)] [stall2] $*"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
until grep -q "stall diag done" ../probe/stall.out 2>/dev/null; do sleep 30; done
PY='C:\ecgbench\venv\Scripts\python.exe'
for cfg in "70 plain" "70 pin"; do set -- $cfg; gap=$1; mode=$2
  [ $mode = pin ] && ps charlie "& $PY C:\ecgbench\tmp\zepin.py 2500 2500 | Out-Null"
  log "== charlie stage2 idle-gap ${gap}ms [$mode]"
  ps charlie "& 'C:\ecgbench\harness\win\launch.ps1' -Cmd '\"$PY\" C:\ecgbench\tmp\zefreq.py 70 0.2' -Log 'C:\ecgbench\results\stall2_freq_$mode.log' -Priority Normal" >/dev/null
  ps charlie "\$env:NSTEP='200'; \$env:SLEEP_MS='$gap'; & $PY C:\ecgbench\tmp\stage_profile.py C:\ecgbench\shards\q122-sym-3\stage2 3072 GPU 2>&1" | grep -v "^Warning" | grep -E "decode T=1|slowest|percentiles|steps >2x" | cut -c1-240
  ps charlie "Start-Sleep 2; Get-Content C:\ecgbench\results\stall2_freq_$mode.log | Select-String domain0 | % { \$_.Line }" | grep -v "^Warning" | tr -s ' ' | cut -c1-200
  [ $mode = pin ] && ps charlie "& $PY C:\ecgbench\tmp\zepin.py 100 2500 | Out-Null"
done
log "== charlie stage2 no gap, 200 steps (control)"
ps charlie "\$env:NSTEP='200'; & $PY C:\ecgbench\tmp\stage_profile.py C:\ecgbench\shards\q122-sym-3\stage2 3072 GPU 2>&1" | grep -v "^Warning" | grep -E "decode T=1|slowest|percentiles|steps >2x" | cut -c1-240
log "stall diag2 done"
