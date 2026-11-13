#!/bin/bash
cd "$(dirname "$0")"; source ./hosts.sh
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
until ps alpha "Test-Path C:\ecgbench\results\G2-122b-3nuc-throttle-high\bench.jsonl" | tail -1 | grep -q True; do sleep 30; done
sleep 60
for h in alpha beta; do echo "== $h during G2 (unpinned, throttle HIGH)"; ps $h "& C:\ecgbench\venv\Scripts\python.exe C:\ecgbench\tmp\zefreq.py 45 0.25 2>&1 | % { \"\$_\" }" | grep -v "^Warning" | grep -E "domain0|domain1" | tr -s ' '; done
echo FREQ_G2_DONE
