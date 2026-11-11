#!/bin/bash
cd "$(dirname "$0")"; source ./hosts.sh
log(){ echo "[$(date +%H:%M:%S)] [mixed] $*"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
R='C:\ecgbench\results\C3-mixed-alphaGPU-charlieCPU'; HZ='C:\ecgbench\harness'
# 1. wait for the stage0 copy
while ! grep -q STAGE0_COPY_DONE ../probe/stage0_copy.out 2>/dev/null; do sleep 30; done
log "copy: $(grep -E 'rc=' ../probe/stage0_copy.out | tail -1)"
V=$(ps alpha "'alpha manifest=' + (Get-FileHash C:\ecgbench\shards\q36-2stage\manifest.json).Hash.Substring(0,16) + ' stage0MB=' + [math]::Round((Get-ChildItem C:\ecgbench\shards\q36-2stage\stage0 -Recurse -File | Measure-Object Length -Sum).Sum/1MB) + ' free=' + [math]::Round((Get-PSDrive C).Free/1GB,1)" | tail -1); log "$V"
MIXED_OK=1; echo "$V" | grep -q "manifest=3E78077A9E2B8D0B" || MIXED_OK=0; echo "$V" | grep -qE "stage0MB=83[0-9][0-9]" || MIXED_OK=0
# 2. wait for charlie's 35B IR download (marker), max 45 min
t0=$(date +%s); while [ $(( $(date +%s)-t0 )) -lt 2700 ]; do ps charlie "Test-Path C:\ecgbench\results\dl35b.done" | tail -1 | grep -q True && break; sleep 60; done
log "charlie IR: $(ps charlie "'MB=' + [math]::Round((Get-ChildItem C:\ecgbench\models\Qwen3.6-35B-A3B-int4-ov -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum/1MB) + ' done=' + (Test-Path C:\ecgbench\results\dl35b.done) + ' free=' + [math]::Round((Get-PSDrive C).Free/1GB,1)" | tail -1)"
# 3. mixed pipeline: charlie rank1 (CPU, stage1) <- alpha rank0 (GPU, stage0)
if [ "$MIXED_OK" = 1 ]; then
  log "launch charlie rank1 on CPU, then alpha rank0 on GPU"
  ps charlie "New-Item -ItemType Directory -Force -Path '$R' | Out-Null; & '$HZ\\win\\server.ps1' -Mode worker -Model 'C:\\ecgbench\\shards\\q36-2stage' -Engine qwen35 -Device CPU -Rank 1 -Total 2 -Listen :9100 -CacheDir none -Extra '--prefix-cache-gb 2' -Log '$R\\rank1-charlie-cpu.log'" | tail -1
  sleep 30
  ps alpha "New-Item -ItemType Directory -Force -Path '$R' | Out-Null; & '$HZ\\win\\server.ps1' -Mode worker -Model 'C:\\ecgbench\\shards\\q36-2stage' -Engine qwen35 -Device GPU -Rank 0 -Total 2 -Next 192.168.0.188:9100 -Api ':8130' -CacheDir none -Extra '--prefix-cache-gb 2' -Log '$R\\rank0-alpha-gpu.log'" | tail -1
  NOLAUNCH=1 QUICK=1 REPEATS=2 HEALTH_TIMEOUT=1500 TAGS="config=C3-mixed-2nuc-gpu-head-cpu-tail model=q36-35b stages=2" ./run_config.sh alpha C3-mixed-alphaGPU-charlieCPU 2>&1 | grep -E "HEALTHY|TIMEOUT|FAILED|did not|^bench|^warmup|rc=" | cut -c1-200
  ps charlie "& '$HZ\\win\\stop.ps1' -Match 'cascadia.exe'" | tail -1
  ps alpha "& '$HZ\\win\\stop.ps1' -Match 'cascadia.exe'" | tail -1
  scp -q "${SSHOPTS[@]}" $(target charlie) "C:/ecgbench/results/C3-mixed-alphaGPU-charlieCPU/rank1-charlie-cpu.log" /Users/tatef/Workspaces/cascadia-ecg-bench/results/C3-mixed-alphaGPU-charlieCPU/ 2>/dev/null
  log "mixed done: $(cat /Users/tatef/Workspaces/cascadia-ecg-bench/results/C3-mixed-alphaGPU-charlieCPU/STATUS 2>/dev/null)"
else
  log "mixed SKIPPED (stage0 copy/manifest check failed)"
fi
# 4. HETERO:GPU,CPU whole 35B on charlie (quoted device)
if ps charlie "Test-Path C:\ecgbench\results\dl35b.done" | tail -1 | grep -q True; then
  log "HETERO retry on charlie (quoted device)"
  QUICK=1 REPEATS=1 HEALTH_TIMEOUT=900 MODEL='C:\ecgbench\models\Qwen3.6-35B-A3B-int4-ov' ENGINE=ov-genai DEVICE='HETERO:GPU,CPU' TAGS="config=E-35b-hetero host=charlie model=q36-35b device=HETERO" ./run_config.sh charlie E-charlie-35b-hetero2 2>&1 | grep -E "HEALTHY|TIMEOUT|FAILED|did not|^bench|^warmup|rc=|error" | cut -c1-200
  log "hetero done: $(cat /Users/tatef/Workspaces/cascadia-ecg-bench/results/E-charlie-35b-hetero2/STATUS 2>/dev/null)"
else
  log "HETERO SKIPPED (no IR on charlie)"
fi
# 5. cleanup for D3
ps alpha "Remove-Item -Recurse -Force C:\ecgbench\shards\q36-2stage -ErrorAction SilentlyContinue; 'alpha free=' + [math]::Round((Get-PSDrive C).Free/1GB,1)" | tail -1
ps charlie "Remove-Item -Recurse -Force C:\ecgbench\models\Qwen3.6-35B-A3B-int4-ov, C:\ecgbench\results\dl35b.done -ErrorAction SilentlyContinue; 'charlie free=' + [math]::Round((Get-PSDrive C).Free/1GB,1)" | tail -1
echo "[$(date +%H:%M:%S)] [alpha-followup] alpha follow-up done" >> ../probe/alpha_b4.out
log "released D3"
