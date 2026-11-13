#!/bin/bash
cd "$(dirname "$0")"
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
until grep -q "t07 spec chain done" ../probe/t07spec4.out 2>/dev/null; do sleep 60; done
echo "[$(date +%H:%M:%S)] [rebuild] fetching bundle + building on tate-07"
ps tate07 "Set-Location C:\ecgbench\src\cascadia; git fetch -q C:\ecgbench\cascadia-spec2.bundle 'refs/heads/ecg/spec-decode:refs/remotes/bundle3/ecg/spec-decode' 2>&1 | Select -Last 1; git checkout -q -B ecg/spec-decode bundle3/ecg/spec-decode 2>&1 | Select -Last 1; 'HEAD=' + (git rev-parse --short HEAD); Remove-Item C:\ecgbench\results\build1.done -ErrorAction SilentlyContinue"
./wbg.sh tate07 'C:\ecgbench\results\build2.log' 'C:\ecgbench\build1.cmd' | tail -1
until ps tate07 "Test-Path C:\ecgbench\results\build1.done" | tail -1 | grep -q True; do sleep 30; done
echo "[$(date +%H:%M:%S)] [rebuild] build done: $(ps tate07 "Get-Content C:\ecgbench\results\build2.log -Tail 2" | tail -2 | tr '\n' ' ' | cut -c1-160)"
ps tate07 "Copy-Item C:\ecgbench\src\cascadia\target\x86_64-pc-windows-msvc\release\cascadia.exe C:\ecgbench\rt\spec\cascadia.exe -Force; 'exe ' + (Get-Item C:\ecgbench\rt\spec\cascadia.exe).LastWriteTime"
echo "REBUILD2_DONE"
