#!/bin/bash
# after the P0 baseline: stop the chain, then hunt the per-step stalls with the standalone OpenVINO profiler + memory counters
cd "$(dirname "$0")"; source ./hosts.sh
log(){ echo "[$(date +%H:%M:%S)] [stall] $*"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
R=/Users/tatef/Workspaces/cascadia-ecg-bench/results
until [ -f "$R/P0-122b-3nuc-newbin-base/STATUS" ]; do sleep 30; done; log "P0 status: $(cat $R/P0-122b-3nuc-newbin-base/STATUS)"
pkill -f nuc_spec122.sh; pkill -f run_chain.sh; pkill -f "run_config.sh alpha"; sleep 2
for h in alpha beta charlie; do ps $h "& 'C:\ecgbench\harness\win\stop.ps1' -Match 'cascadia.exe' | Select -Last 1" | tail -1 | sed "s/^/$h: /"; done
PY='C:\ecgbench\venv\Scripts\python.exe'
prof(){ local h=$1 st=$2 tag=$3 extra=$4
  ps $h "& 'C:\ecgbench\harness\win\launch.ps1' -Cmd 'typeperf \"\Memory\Pages Input/sec\" \"\Memory\Available MBytes\" \"\GPU Adapter Memory(*)\Shared Usage\" \"\GPU Adapter Memory(*)\Total Committed\" \"\GPU Engine(*engtype_Copy)\Utilization Percentage\" -si 1 -sc 150 -o C:\ecgbench\results\stall_$tag.csv -y' -Log 'C:\ecgbench\results\stall_$tag.typeperf.log' -Priority Normal" >/dev/null
  log "== $h $st [$tag] $extra"
  ps $h "\$env:NSTEP='300'; & $PY C:\ecgbench\tmp\stage_profile.py C:\ecgbench\shards\q122-sym-3\\$st 3072 GPU $extra 2>&1" | grep -v "^Warning" | grep -E "compiled|prefill|decode T=1|slowest|percentiles|steps >2x|last decode" | cut -c1-240
  ps $h "Start-Sleep 3; Get-Process typeperf -ErrorAction SilentlyContinue | Stop-Process -Force; \$c=Import-Csv C:\ecgbench\results\stall_$tag.csv; \$cols=\$c[0].PSObject.Properties.Name; foreach (\$k in \$cols[1..(\$cols.Count-1)]) { \$v=\$c | % { [double](\$_.\$k) } | ? { \$_ -ge 0 }; if (\$v) { (\$k -replace '.*\\\\','') + ' min=' + [math]::Round((\$v | Measure -Min).Minimum) + ' max=' + [math]::Round((\$v | Measure -Max).Maximum) + ' mean=' + [math]::Round((\$v | Measure -Average).Average) } }" | grep -v "^Warning" | grep -E "Pages|Available|Shared|Committed|Utilization" | head -8
}
prof charlie stage2 c2_plain ""
prof charlie stage2 c2_cache "CACHE_DIR=C:\ecgbench\ovcache_stall"
prof charlie stage2 c2_cache2 "CACHE_DIR=C:\ecgbench\ovcache_stall"
prof alpha stage0 a0_plain ""
log "stall diag done"
