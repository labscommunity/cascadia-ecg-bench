#!/bin/bash
# D2: Qwen3.5-122B-A10B int4, 4-stage pipeline: alpha(stage0+embeddings) -> beta(stage1) -> charlie(stage2) -> tate-07(stage3+lm_head, 18 layers) over the tailnet relay.
cd "$(dirname "$0")"; source ./hosts.sh
S="-o ConnectTimeout=20 -o BatchMode=yes -o LogLevel=ERROR -o StrictHostKeyChecking=accept-new"
label=D2-122b-4stage-3nuc-tate07; OUT="/Users/tatef/Workspaces/cascadia-ecg-bench/results/$label"; mkdir -p "$OUT"
L=/Users/tatef/q122-stages-4; PRO="tatef@192.168.0.213"   # wired 2.5 GbE; the `pro` alias is the Wi-Fi interface (7 MB/s)
log(){ echo "[$(date +%H:%M:%S)] [d2] $*" | tee -a "$OUT/orchestrator.log"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
# 1. wait for the VM -> pro copy (4 stage dirs + manifest present and scp gone)
until ssh $S pro 'test -f ~/q122-stages-4/manifest.json && test -d ~/q122-stages-4/stage3 && ! pgrep -f "scp -q -P 2222" >/dev/null' 2>/dev/null; do sleep 120; done
log "pro has the 4-stage tree: $(ssh $S pro 'du -sh ~/q122-stages-4/* | tr "\n" " "')"
# 2. make room on alpha/beta (35B stage trees are no longer needed there), create dirs
ps alpha "Remove-Item -Recurse -Force C:\ecgbench\shards\q36-2stage, C:\ecgbench\shards\q36-3stage -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force -Path C:\ecgbench\shards\q122-4stage | Out-Null; 'alpha free GB=' + [math]::Round((Get-PSDrive C).Free/1GB,1)" | tail -1 | tee -a "$OUT/orchestrator.log"
ps beta "Remove-Item -Recurse -Force C:\ecgbench\shards\q36-3stage -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force -Path C:\ecgbench\shards\q122-4stage | Out-Null; 'beta free GB=' + [math]::Round((Get-PSDrive C).Free/1GB,1)" | tail -1 | tee -a "$OUT/orchestrator.log"
ps charlie "New-Item -ItemType Directory -Force -Path C:\ecgbench\shards\q122-4stage | Out-Null; 'charlie free GB=' + [math]::Round((Get-PSDrive C).Free/1GB,1)" | tail -1 | tee -a "$OUT/orchestrator.log"
ps tate07 "New-Item -ItemType Directory -Force -Path C:\ecgbench\shards\q122-4stage | Out-Null; 'tate07 free GB=' + [math]::Round((Get-PSDrive C).Free/1GB,1)" | tail -1 | tee -a "$OUT/orchestrator.log"
# 3. distribute: NUCs over the LAN (scp -3 via this Mac), tate-07 via the bastion (scp -3)
ROOT="chat_template.jinja config.json generation_config.json manifest.json openvino_text_embeddings_model.bin openvino_text_embeddings_model.xml tokenizer.json"
A=tatef@192.168.0.101; B=tatef@192.168.0.103; C=tatef@192.168.0.188; K="-i $HOME/.ssh/id_ed25519"
t0=$(date +%s)
for f in $ROOT; do for t in "$A" "$B" "$C"; do scp -3 -q $S $K "$PRO:$L/$f" "$t:C:/ecgbench/shards/q122-4stage/$f"; done; scp -3 -q $S -i $HOME/.ssh/id_ed25519 "$PRO:$L/$f" "cascadia-tate-07:C:/ecgbench/shards/q122-4stage/$f" || scp -3 -q $S -i $HOME/.ssh/id_ed25519 "$PRO:$L/$f" "cascadia-tate-07-ts:C:/ecgbench/shards/q122-4stage/$f"; done
log "root files out in $(( $(date +%s)-t0 ))s"
( scp -3 -q $S $K -r "$PRO:$L/stage0" "$A:C:/ecgbench/shards/q122-4stage/" && log "alpha stage0 done" ) &
( scp -3 -q $S $K -r "$PRO:$L/stage1" "$B:C:/ecgbench/shards/q122-4stage/" && log "beta stage1 done" ) &
( scp -3 -q $S $K -r "$PRO:$L/stage2" "$C:C:/ecgbench/shards/q122-4stage/" && log "charlie stage2 done" ) &
( scp -3 -q $S -i $HOME/.ssh/id_ed25519 -r "$PRO:$L/stage3" "cascadia-tate-07:C:/ecgbench/shards/q122-4stage/" && log "tate07 stage3 done" || { log "tate07 bastion copy failed, retry via tailnet"; scp -3 -q $S -i $HOME/.ssh/id_ed25519 -r "$PRO:$L/stage3" "cascadia-tate-07-ts:C:/ecgbench/shards/q122-4stage/" && log "tate07 stage3 done (tailnet)"; } ) &
wait; log "distribution done in $(( $(date +%s)-t0 ))s"
for h in alpha beta charlie tate07; do ps $h "'$h manifest=' + (Get-FileHash C:\ecgbench\shards\q122-4stage\manifest.json).Hash.Substring(0,16) + ' ' + ((Get-ChildItem C:\ecgbench\shards\q122-4stage -Directory | % { \$_.Name + '=' + [math]::Round((Get-ChildItem \$_.FullName -Recurse -File | Measure-Object Length -Sum).Sum/1GB,1) + 'GB' }) -join ' ')" | tail -1 | tee -a "$OUT/orchestrator.log"; done
# 4. pause honyaku again (user-approved) + watchdogs
for h in alpha beta; do ps $h "foreach (\$t in @('honyaku-watchdog','cascadia-watchdog')) { Disable-ScheduledTask -TaskName \$t -ErrorAction SilentlyContinue | Out-Null }; & powershell -NoProfile -ExecutionPolicy Bypass -File C:\cascadia-honyaku\ranks.ps1 stop; 'FREE_RAM_GB=' + [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB,1)" | tail -3 | sed "s/^/$h: /" | tee -a "$OUT/orchestrator.log"; done
rm -f /tmp/restore_nucs.done
# 5. launch ranks 3 -> 0
R="C:\\ecgbench\\results\\$label"; HZ='C:\ecgbench\harness'
for h in alpha beta charlie tate07; do ps $h "New-Item -ItemType Directory -Force -Path '$R' | Out-Null; 'ok'" >/dev/null; done
log "launch rank 3 on tate-07 (:9300)"
ps tate07 "& '$HZ\\win\\server.ps1' -Mode worker -Model 'C:\\ecgbench\\shards\\q122-4stage' -Engine qwen35 -Device GPU -Rank 3 -Total 4 -Listen :9300 -CacheDir none -Extra '--prefix-cache-gb 0' -Log '$R\\rank3.log'" | grep -E "LAUNCH" | tee -a "$OUT/orchestrator.log"
ps tate07 "New-NetFirewallRule -DisplayName ecgbench-9300 -Direction Inbound -Protocol TCP -LocalPort 9300 -Action Allow -ErrorAction SilentlyContinue | Out-Null; 'fw ok'" >/dev/null
sleep 30
log "launch rank 2 on charlie (:9100 -> tate-07 tailnet :9300)"
ps charlie "& '$HZ\\win\\server.ps1' -Mode worker -Model 'C:\\ecgbench\\shards\\q122-4stage' -Engine qwen35 -Device GPU -Rank 2 -Total 4 -Listen :9100 -Next 100.82.253.76:9300 -CacheDir none -Extra '--prefix-cache-gb 0' -Log '$R\\rank2.log'" | grep -E "LAUNCH" | tee -a "$OUT/orchestrator.log"
sleep 20
log "launch rank 1 on beta (:9100 -> charlie)"
ps beta "& '$HZ\\win\\server.ps1' -Mode worker -Model 'C:\\ecgbench\\shards\\q122-4stage' -Engine qwen35 -Device GPU -Rank 1 -Total 4 -Listen :9100 -Next 192.168.0.188:9100 -CacheDir none -Extra '--prefix-cache-gb 0' -Log '$R\\rank1.log'" | grep -E "LAUNCH" | tee -a "$OUT/orchestrator.log"
sleep 20
log "launch rank 0 on alpha (API :8130 -> beta)"
ps alpha "& '$HZ\\win\\server.ps1' -Mode worker -Model 'C:\\ecgbench\\shards\\q122-4stage' -Engine qwen35 -Device GPU -Rank 0 -Total 4 -Next 192.168.0.103:9100 -Api ':8130' -CacheDir none -Extra '--prefix-cache-gb 0' -Log '$R\\rank0.log'" | grep -E "LAUNCH" | tee -a "$OUT/orchestrator.log"
# 6. measurement on the head (bench 2 repeats to save time), steady, chain-wide window
NOLAUNCH=1 NOSTOP=1 HEALTH_TIMEOUT=2400 REPEATS=2 TAGS="config=D2-122b-4shard-3nuc+tate07 model=q35-122b stages=4" ./run_config.sh alpha "$label"
if [ "$(cat $OUT/STATUS 2>/dev/null)" = "DONE" ]; then
  log "chain-wide steady window on all 4 ranks"
  for h in alpha beta charlie tate07; do ps $h "& '$HZ\\win\\launch.ps1' -Cmd 'powershell -NoProfile -ExecutionPolicy Bypass -File $HZ\\win\\sample.ps1 -Out $R\\steady-$h.util.jsonl -Seconds 95' -Log '$R\\sampler-$h.log' -Priority Normal" >/dev/null & done; wait
  ps alpha "& '$HZ\\win\\launch.ps1' -Cmd '\"C:\\ecgbench\\venv\\Scripts\\python.exe\" $HZ\\bench_client.py --base http://127.0.0.1:8130 --mode steady --seconds 90 --steady-prompt medium --max-tokens 128 --out $R\\steady2.jsonl --tag config=D2 --tag stages=4' -Log '$R\\steady2-client.log' -Priority Normal" >/dev/null
  sleep 12
  for h in alpha beta charlie tate07; do ( ps $h "& '$HZ\\win\\socwatch_run.ps1' -Seconds 60 -Prefix '$R\\steady-$h.sw'" | tail -1 | cut -c1-200 | sed "s/^/$h: /" | tee -a "$OUT/orchestrator.log" ) & done; wait; sleep 25
  log "GSM8K-10 eval (short, the chain is slow)"; N=10 EVAL_TOKENS=400 EVAL_WAIT_MIN=90 TAGS="config=$label stages=4 model=q35-122b" ./run_eval.sh alpha "$label-eval"
fi
# 7. stop ranks, collect, restore honyaku
log "stop ranks"; for h in alpha beta charlie tate07; do ps $h "& '$HZ\\win\\stop.ps1' -Match 'cascadia.exe'" | tail -1 | sed "s/^/$h: /" | tee -a "$OUT/orchestrator.log"; done
for h in alpha beta charlie tate07; do mkdir -p "$OUT/rank-$h"; scp -q "${SSHOPTS[@]}" $(target "$h" | sed 's/-o UserKnownHostsFile=\/dev\/null//') -r "$(target "$h" | awk '{print $NF}'):C:/ecgbench/results/$label/*" "$OUT/rank-$h/" 2>&1 | tail -1; done
log "restore honyaku"; ./restore_nucs.sh >> "$OUT/orchestrator.log" 2>&1
log "D2 chain done"
