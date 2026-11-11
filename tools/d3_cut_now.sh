#!/bin/bash
cd "$(dirname "$0")"; source ./hosts.sh
label=D3-122b-3stage-3nuc; OUT="/Users/tatef/Workspaces/cascadia-ecg-bench/results/$label"
log(){ echo "[$(date +%H:%M:%S)] [d3cut] $*" | tee -a "$OUT/orchestrator.log"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
log "cutting D3 (thrash case: enough data)"
pkill -f d3_chain.sh; pkill -f "run_chain.sh"; pkill -f "run_config.sh alpha $label"; sleep 1
for h in alpha beta charlie; do ps $h "& 'C:\ecgbench\harness\win\stop.ps1' -Match 'powershell' -CmdLike '*health.ps1*' | Select -Last 1; & 'C:\ecgbench\harness\win\stop.ps1' -Match 'python.exe' | Select -Last 1; & 'C:\ecgbench\harness\win\stop.ps1' -Match 'cascadia.exe' | Select -Last 1" | tail -1 | sed "s/^/$h: /"; done
scp -q "${SSHOPTS[@]}" -i "$HOME/.ssh/id_ed25519" -r "tatef@100.115.173.79:C:/ecgbench/results/$label/*" "$OUT/" 2>&1 | tail -1
for h in beta charlie; do mkdir -p "$OUT/rank-$h"; scp -q "${SSHOPTS[@]}" -i "$HOME/.ssh/id_ed25519" -r "$(target $h | awk '{print $NF}'):C:/ecgbench/results/$label/*" "$OUT/rank-$h/" 2>&1 | tail -1; done
echo PARTIAL > "$OUT/STATUS"
log "collected: $(ls $OUT | tr '\n' ' ')"
touch ../probe/d3_stopped; log "D3 cut done"
