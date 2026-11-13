#!/bin/bash
# Pause honyaku (alpha/beta ranks + watchdogs) and Acrow (charlie) for a benchmark window. Undo with restore_nucs.sh.
cd "$(dirname "$0")"; source ./hosts.sh
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
rm -f /tmp/restore_nucs.done
for h in alpha beta; do ps $h "foreach (\$t in @('honyaku-watchdog','cascadia-watchdog')) { Disable-ScheduledTask -TaskName \$t -ErrorAction SilentlyContinue | Out-Null }; & powershell -NoProfile -ExecutionPolicy Bypass -File C:\cascadia-honyaku\ranks.ps1 stop | Out-Null; Start-Sleep 2; '$h honyaku procs=' + (Get-Process cascadia-node-honyaku -ErrorAction SilentlyContinue).Count" | tail -1; done
ps charlie "Stop-ScheduledTask -TaskName cascadia-acrow-node -ErrorAction SilentlyContinue; Get-Process cascadia-node-acrow,ovms -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep 2; 'charlie acrow procs=' + (Get-Process cascadia-node-acrow,ovms -ErrorAction SilentlyContinue).Count" | tail -1
