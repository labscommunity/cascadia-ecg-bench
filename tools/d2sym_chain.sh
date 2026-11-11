#!/bin/bash
# D2sym: Qwen3.5-122B-A10B int4 (--expert-sym), 4 stages: alpha(stage0 13GB) -> beta(stage1 16GB) -> charlie(stage2 16GB) -> tate-07(stage3 26GB) over the tailnet relay.
# Every stage fits its GPU's resident segment (NUC 18.4 GB, tate-07 48 GiB window).
cd "$(dirname "$0")"; source ./hosts.sh
S=(-o ConnectTimeout=20 -o BatchMode=yes -o LogLevel=ERROR -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null)
label=D2sym-122b-4stage-3nuc-tate07; OUT="/Users/tatef/Workspaces/cascadia-ecg-bench/results/$label"; mkdir -p "$OUT"
L=/Users/tatef/q122-sym-stages-4; PRO="tatef@192.168.0.213"; K="-i $HOME/.ssh/id_ed25519"
A=tatef@192.168.0.101; B=tatef@192.168.0.103; C=tatef@192.168.0.188; T07TS=100.82.253.76
TREE='C:\ecgbench\shards\q122-sym-4'; D=C:/ecgbench/shards/q122-sym-4; HZ='C:\ecgbench\harness'; R="C:\\ecgbench\\results\\$label"
log(){ echo "[$(date +%H:%M:%S)] [d2sym] $*" | tee -a "$OUT/orchestrator.log"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
# 0. wait: D3 stopped, stage3 on tate-07, stage2 complete on pro
until [ -f ../probe/d3_stopped ]; do sleep 60; done; log "D3 stopped"
until ssh "${S[@]}" $PRO "test \$(du -sm $L/stage2 | cut -f1) -ge 16090 && ! ls $L/stage2/.stage.bin.* >/dev/null 2>&1 && ! pgrep -f 'rsync -a --exclude' >/dev/null" 2>/dev/null; do sleep 60; done; log "stage2 complete on pro"
# 1. NUC prep: drop the 3-stage tree (D3 done), make dirs
for h in alpha beta charlie; do ps $h "Remove-Item -Recurse -Force C:\ecgbench\shards\q122-sym-3 -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force -Path $TREE | Out-Null; '$h free GB=' + [math]::Round((Get-PSDrive C).Free/1GB,1)" | tail -1 | tee -a "$OUT/orchestrator.log"; done
# 2. distribute to the NUCs over the LAN (through this Mac)
ROOT="chat_template.jinja config.json generation_config.json manifest.json openvino_text_embeddings_model.bin openvino_text_embeddings_model.xml tokenizer.json"
t0=$(date +%s)
for f in $ROOT; do for t in "$A" "$B" "$C"; do scp -3 -q "${S[@]}" $K "$PRO:$L/$f" "$t:$D/$f"; done; done; log "root files on NUCs"
( scp -3 -q "${S[@]}" $K -r "$PRO:$L/stage0" "$A:$D/" && log "alpha stage0 done" ) &
( scp -3 -q "${S[@]}" $K -r "$PRO:$L/stage1" "$B:$D/" && log "beta stage1 done" ) &
( scp -3 -q "${S[@]}" $K -r "$PRO:$L/stage2" "$C:$D/" && log "charlie stage2 done" ) &
wait; log "NUC distribution done in $(( $(date +%s)-t0 ))s"
until [ -f ../probe/stage3_tate07.done ]; do sleep 60; done; log "stage3 on tate-07: $(tail -2 ../probe/stage3_tate07.out | head -1)"
for h in alpha beta charlie tate07; do ps $h "'$h manifest=' + (Get-FileHash $TREE\manifest.json).Hash.Substring(0,16) + ' ' + ((Get-ChildItem $TREE -Directory | % { \$_.Name + '=' + [math]::Round((Get-ChildItem \$_.FullName -Recurse -File | Measure-Object Length -Sum).Sum/1GB,1) + 'GB' }) -join ' ')" | tail -1 | tee -a "$OUT/orchestrator.log"; done
# 3. tate-07: take the enterprise node down for the run (restored at the end)
ps tate07 "Set-Service cascadia-node -StartupType Disabled; Stop-Service cascadia-node -Force -ErrorAction SilentlyContinue; Start-Sleep 5; Get-Process ovms,cascadia-node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep 3; 'tate07 svc=' + (Get-Service cascadia-node).Status + ' procs=' + ((Get-Process ovms,cascadia-node,cascadia -ErrorAction SilentlyContinue | % Name) -join ',')" | tail -1 | tee -a "$OUT/orchestrator.log"
# 4. honyaku stays paused (already), reset restore guard
for h in alpha beta; do ps $h "foreach (\$t in @('honyaku-watchdog','cascadia-watchdog')) { Disable-ScheduledTask -TaskName \$t -ErrorAction SilentlyContinue | Out-Null }; & powershell -NoProfile -ExecutionPolicy Bypass -File C:\cascadia-honyaku\ranks.ps1 stop | Out-Null; 'FREE_RAM_GB=' + [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB,1)" | tail -1 | sed "s/^/$h: /" | tee -a "$OUT/orchestrator.log"; done
rm -f /tmp/restore_nucs.done
# 5. launch ranks 3 -> 0
for h in alpha beta charlie tate07; do ps $h "New-Item -ItemType Directory -Force -Path '$R' | Out-Null; 'ok'" >/dev/null; done
log "launch rank 3 on tate-07 (:9300)"
ps tate07 "New-NetFirewallRule -DisplayName ecgbench-9300 -Direction Inbound -Protocol TCP -LocalPort 9300 -Action Allow -ErrorAction SilentlyContinue | Out-Null; & '$HZ\\win\\server.ps1' -Mode worker -Model '$TREE' -Engine qwen35 -Device GPU -Rank 3 -Total 4 -Listen :9300 -CacheDir none -Extra '--prefix-cache-gb 0' -Log '$R\\rank3.log'" | grep -E "LAUNCH" | tee -a "$OUT/orchestrator.log"
sleep 45
log "launch rank 2 on charlie (:9100 -> tate-07 tailnet :9300)"
ps charlie "& '$HZ\\win\\server.ps1' -Mode worker -Model '$TREE' -Engine qwen35 -Device GPU -Rank 2 -Total 4 -Listen :9100 -Next $T07TS:9300 -CacheDir none -Extra '--prefix-cache-gb 0' -Log '$R\\rank2.log'" | grep -E "LAUNCH" | tee -a "$OUT/orchestrator.log"
sleep 20
log "launch rank 1 on beta (:9100 -> charlie)"
ps beta "& '$HZ\\win\\server.ps1' -Mode worker -Model '$TREE' -Engine qwen35 -Device GPU -Rank 1 -Total 4 -Listen :9100 -Next 192.168.0.188:9100 -CacheDir none -Extra '--prefix-cache-gb 0' -Log '$R\\rank1.log'" | grep -E "LAUNCH" | tee -a "$OUT/orchestrator.log"
sleep 20
log "launch rank 0 on alpha (API :8130 -> beta)"
ps alpha "& '$HZ\\win\\server.ps1' -Mode worker -Model '$TREE' -Engine qwen35 -Device GPU -Rank 0 -Total 4 -Next 192.168.0.103:9100 -Api ':8130' -CacheDir none -Extra '--prefix-cache-gb 0' -Log '$R\\rank0.log'" | grep -E "LAUNCH" | tee -a "$OUT/orchestrator.log"
# 6. measurement on the head, chain-wide window, eval
NOLAUNCH=1 NOSTOP=1 HEALTH_TIMEOUT=2400 REPEATS=2 TAGS="config=D2sym-122b-4shard-3nuc+tate07 model=q35-122b stages=4" ./run_config.sh alpha "$label"
if [ "$(cat $OUT/STATUS 2>/dev/null)" = "DONE" ]; then
  log "chain-wide steady window on all 4 ranks"
  for h in alpha beta charlie tate07; do ps $h "& '$HZ\\win\\launch.ps1' -Cmd 'powershell -NoProfile -ExecutionPolicy Bypass -File $HZ\\win\\sample.ps1 -Out $R\\steady-$h.util.jsonl -Seconds 95' -Log '$R\\sampler-$h.log' -Priority Normal" >/dev/null & done; wait
  ps alpha "& '$HZ\\win\\launch.ps1' -Cmd '\"C:\\ecgbench\\venv\\Scripts\\python.exe\" $HZ\\bench_client.py --base http://127.0.0.1:8130 --mode steady --seconds 90 --steady-prompt medium --max-tokens 128 --out $R\\steady2.jsonl --tag config=D2sym --tag stages=4' -Log '$R\\steady2-client.log' -Priority Normal" >/dev/null
  sleep 12
  for h in alpha beta charlie tate07; do ( ps $h "& '$HZ\\win\\socwatch_run.ps1' -Seconds 60 -Prefix '$R\\steady-$h.sw'" | tail -1 | cut -c1-200 | sed "s/^/$h: /" | tee -a "$OUT/orchestrator.log" ) & done; wait; sleep 25
  log "GSM8K-20 eval"; N=20 EVAL_TOKENS=400 EVAL_WAIT_MIN=120 TAGS="config=$label stages=4 model=q35-122b" ./run_eval.sh alpha "$label-eval"
fi
# 7. stop ranks, collect, restore
log "stop ranks"; for h in alpha beta charlie tate07; do ps $h "& '$HZ\\win\\stop.ps1' -Match 'cascadia.exe'" | tail -1 | sed "s/^/$h: /" | tee -a "$OUT/orchestrator.log"; done
for h in beta charlie; do mkdir -p "$OUT/rank-$h"; scp -q "${SSHOPTS[@]}" $K -r "$(target $h | awk '{print $NF}'):C:/ecgbench/results/$label/*" "$OUT/rank-$h/" 2>&1 | tail -1; done
mkdir -p "$OUT/rank-alpha" "$OUT/rank-tate07"; scp -q "${SSHOPTS[@]}" $K -r "$A:C:/ecgbench/results/$label/*" "$OUT/rank-alpha/" 2>&1 | tail -1
scp -q "${SSHOPTS[@]}" -o UserKnownHostsFile=/dev/null -r "cascadia-tate-07-ts:C:/ecgbench/results/$label/*" "$OUT/rank-tate07/" 2>&1 | tail -1
log "restore tate-07 service"; ps tate07 "Set-Service cascadia-node -StartupType Automatic; Start-Service cascadia-node; Start-Sleep 10; 'tate07 svc=' + (Get-Service cascadia-node).Status + ' start=' + (Get-Service cascadia-node).StartType" | tail -1 | tee -a "$OUT/orchestrator.log"
log "restore honyaku + acrow"; ./restore_nucs.sh >> "$OUT/orchestrator.log" 2>&1
log "D2sym chain done"
