#!/bin/bash
# whole-model speculative decoding on tate-07 with the released runtime's existing flags (prompt lookup; FastDraft with a 0.8B draft)
cd "$(dirname "$0")"; source ./hosts.sh
log(){ echo "[$(date +%H:%M:%S)] [t07spec] $*"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
HZ='C:\ecgbench\harness'; OFF='C:\ecgbench\models\Qwen3.6-35B-A3B-int4-ov'; SYM='C:\ecgbench\models\q35-gptq-sym-ov'; DR='C:\ecgbench\models\Qwen3.5-0.8B-int4-ov'
R=/Users/tatef/Workspaces/cascadia-ecg-bench/results
ps tate07 "Set-Service cascadia-node -StartupType Disabled; Stop-Service cascadia-node -Force -ErrorAction SilentlyContinue; Start-Sleep 5; Get-Process ovms,cascadia-node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep 3; 'tate07 svc=' + (Get-Service cascadia-node).Status + ' procs=' + ((Get-Process ovms,cascadia-node,cascadia -ErrorAction SilentlyContinue | % Name) -join ',')" | tail -1
export EXE="C:\\ecgbench\\rt\\spec\\cascadia.exe"
run(){ local label=$1 model=$2 extra=$3; local RW="C:\\ecgbench\\results\\$label"
  ps tate07 "New-Item -ItemType Directory -Force -Path '$RW' | Out-Null; & '$HZ\\win\\server.ps1' -Exe 'C:\\ecgbench\\rt\\spec\\cascadia.exe' -Mode worker -Model '$model' -Engine ov-genai -Device GPU -Rank 0 -Total 1 -Api ':8130' -CacheDir none -Extra '$extra' -Log '$RW\\server.log'" | grep -E "CMD|LAUNCH" | cut -c1-220
  NOLAUNCH=1 QUICK=1 REPEATS=2 HEALTH_TIMEOUT=900 TAGS="config=$label host=tate07 model=q36-35b spec=${extra// /_}" ./run_config.sh tate07 "$label" 2>&1 | grep -E "HEALTHY|TIMEOUT|FAILED|did not|^bench|rror" | cut -c1-200
  ps tate07 "Get-Content '$RW\\server.log' -Tail 400 | Select-String -Pattern 'spec|draft|lookup|accept|assist|rror' | Select -Last 6 | % { \$_.Line.Substring(0,[math]::Min(220,\$_.Line.Length)) }" | grep -v "^Warning"
  ps tate07 "& '$HZ\\win\\stop.ps1' -Match 'cascadia.exe' | Select -Last 1" | tail -1
  log "$label: $(cat $R/$label/STATUS 2>/dev/null)"
}
run S0c-tate07-35b-worker-base-newbin "$OFF" ""
run S1n-tate07-35b-prompt-lookup3-k5 "$OFF" "--prompt-lookup 3 --spec-k 5"
run S2n-tate07-35b-prompt-lookup2-k8 "$OFF" "--prompt-lookup 2 --spec-k 8"
run S3n-tate07-35bsym-draft08b-gpu-k5 "$SYM" "--draft-model $DR --spec-k 5"
run S4n-tate07-35bsym-draft08b-cpu-k5 "$SYM" "--draft-model $DR --draft-device CPU --spec-k 5"
run S5n-tate07-35bsym-worker-base "$SYM" ""
run S6n-tate07-35b-draft08b-official "$OFF" "--draft-model $DR --spec-k 5"
log "restore tate-07 service"; ps tate07 "Set-Service cascadia-node -StartupType Automatic; Start-Service cascadia-node; Start-Sleep 10; 'tate07 svc=' + (Get-Service cascadia-node).Status + ' start=' + (Get-Service cascadia-node).StartType" | tail -1
log "t07 spec chain done"
