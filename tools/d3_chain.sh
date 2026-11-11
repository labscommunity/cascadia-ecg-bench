#!/bin/bash
# D3: Qwen3.5-122B-A10B int4 (--expert-sym build), 3 even stages on alpha/beta/charlie with 85% GPU windows (all-local 2.5 GbE pipeline).
cd "$(dirname "$0")"; source ./hosts.sh
label=D3-122b-3stage-3nuc; OUT="/Users/tatef/Workspaces/cascadia-ecg-bench/results/$label"; mkdir -p "$OUT"
S=(-o ConnectTimeout=20 -o BatchMode=yes -o LogLevel=ERROR -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null)
log(){ echo "[$(date +%H:%M:%S)] [d3] $*" | tee -a "$OUT/orchestrator.log"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
until grep -q "q122-sym-stages-3 on pro" ../probe/sym_followup.out 2>/dev/null; do sleep 120; done
until grep -q "alpha follow-up done" ../probe/alpha_b4.out 2>/dev/null; do sleep 60; done
log "tree on pro and alpha free; sizes: $(ssh "${S[@]}" pro 'du -sh ~/q122-sym-stages-3/* | tr "\n" " "')"
# disk: alpha drops its 35B IR (re-downloadable); beta needs ~22 GB (has ~17): drop its old backup of the June demo tree (C:\Cascadia-backup-20260911-120738, 31 GB, a copy of C:\Cascadia)
ps alpha "Remove-Item -Recurse -Force C:\ecgbench\models\Qwen3.6-35B-A3B-int4-ov -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force -Path C:\ecgbench\shards\q122-sym-3 | Out-Null; 'alpha free GB=' + [math]::Round((Get-PSDrive C).Free/1GB,1)" | tail -1 | tee -a "$OUT/orchestrator.log"
ps beta "if ((Get-PSDrive C).Free/1GB -lt 24) { Remove-Item -Recurse -Force 'C:\Cascadia-backup-20260911-120738' -ErrorAction SilentlyContinue; 'beta: removed C:\Cascadia-backup-20260911-120738 (Sept backup copy of C:\Cascadia) to make room' }; New-Item -ItemType Directory -Force -Path C:\ecgbench\shards\q122-sym-3 | Out-Null; 'beta free GB=' + [math]::Round((Get-PSDrive C).Free/1GB,1)" | tail -2 | tee -a "$OUT/orchestrator.log"
ps charlie "Remove-Item -Recurse -Force C:\ecgbench\shards\q36-2stage, C:\ecgbench\shards\q36-3stage -ErrorAction SilentlyContinue; New-Item -ItemType Directory -Force -Path C:\ecgbench\shards\q122-sym-3 | Out-Null; 'charlie free GB=' + [math]::Round((Get-PSDrive C).Free/1GB,1)" | tail -1 | tee -a "$OUT/orchestrator.log"
for h in alpha beta charlie; do f=$(ps $h "[math]::Round((Get-PSDrive C).Free/1GB,0)" | tail -1 | tr -d '\r'); log "$h free ${f} GB"; [ "${f:-0}" -lt 27 ] && log "WARNING: $h has < 27 GB free for a 20-24 GB stage"; done
ROOT="chat_template.jinja config.json generation_config.json manifest.json openvino_text_embeddings_model.bin openvino_text_embeddings_model.xml tokenizer.json"
PRO="tatef@192.168.0.213"; K="-i $HOME/.ssh/id_ed25519"; A=tatef@192.168.0.101; B=tatef@192.168.0.103; C=tatef@192.168.0.188
t0=$(date +%s)
for f in $ROOT; do for t in "$A" "$B" "$C"; do scp -3 -q "${S[@]}" $K "$PRO:~/q122-sym-stages-3/$f" "$t:C:/ecgbench/shards/q122-sym-3/$f"; done; done
( scp -3 -q "${S[@]}" $K -r "$PRO:~/q122-sym-stages-3/stage0" "$A:C:/ecgbench/shards/q122-sym-3/" && log "alpha stage0 done" ) &
( scp -3 -q "${S[@]}" $K -r "$PRO:~/q122-sym-stages-3/stage1" "$B:C:/ecgbench/shards/q122-sym-3/" && log "beta stage1 done" ) &
( scp -3 -q "${S[@]}" $K -r "$PRO:~/q122-sym-stages-3/stage2" "$C:C:/ecgbench/shards/q122-sym-3/" && log "charlie stage2 done" ) &
wait; log "distribution done in $(( $(date +%s)-t0 ))s"
for h in alpha beta charlie; do ps $h "'$h manifest=' + (Get-FileHash C:\ecgbench\shards\q122-sym-3\manifest.json).Hash.Substring(0,16) + ' ' + ((Get-ChildItem C:\ecgbench\shards\q122-sym-3 -Directory | % { \$_.Name + '=' + [math]::Round((Get-ChildItem \$_.FullName -Recurse -File | Measure-Object Length -Sum).Sum/1GB,1) + 'GB' }) -join ' ') + ' free=' + [math]::Round((Get-PSDrive C).Free/1GB,1)" | tail -1 | tee -a "$OUT/orchestrator.log"; done
# pause honyaku (if it came back) and run the chain with the standard measurement + eval (N=20) + restore
for h in alpha beta; do ps $h "foreach (\$t in @('honyaku-watchdog','cascadia-watchdog')) { Disable-ScheduledTask -TaskName \$t -ErrorAction SilentlyContinue | Out-Null }; & powershell -NoProfile -ExecutionPolicy Bypass -File C:\cascadia-honyaku\ranks.ps1 stop" | tail -1; done
rm -f /tmp/restore_nucs.done
TREE='C:\ecgbench\shards\q122-sym-3' HOSTS="alpha beta charlie" IPS="192.168.0.101 192.168.0.103 192.168.0.188" MODEL_TAG=q35-122b EVAL_TOKENS=400 EVAL_N=20 EVAL_WAIT_MIN=90 TAGS="config=D3-122b-3shard-3nuc model=q35-122b" ./run_chain.sh "$label"
log "run_chain finished; restoring honyaku"; ./restore_nucs.sh >> "$OUT/orchestrator.log" 2>&1
log "D3 chain done"
