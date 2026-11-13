#!/bin/bash
# stream pro:~/q122-sym-stages-3 root files + stage0 to alpha (C:\ecgbench\shards\q122-sym-3) through this Mac
cd "$(dirname "$0")"; source ./hosts.sh
S=(-o ConnectTimeout=20 -o BatchMode=yes -o LogLevel=ERROR -o StrictHostKeyChecking=accept-new)
PRO=tatef@192.168.0.213; L=/Users/tatef/q122-sym-stages-3; K="-i $HOME/.ssh/id_ed25519"
log(){ echo "[$(date +%H:%M:%S)] [s0] $*"; }
A=tatef@192.168.0.101
ssh "${S[@]}" $K $A hostname >/dev/null 2>&1 || A=tatef@100.115.173.79
log "alpha target $A"
ssh "${S[@]}" $K $A 'powershell -NoProfile -Command "New-Item -ItemType Directory -Force -Path C:\ecgbench\shards\q122-sym-3\stage0 | Out-Null; (Get-PSDrive C).Free/1GB"'
D=C:/ecgbench/shards/q122-sym-3
ROOT="chat_template.jinja config.json generation_config.json manifest.json openvino_text_embeddings_model.bin openvino_text_embeddings_model.xml tokenizer.json"
for f in $ROOT; do scp -3 -q "${S[@]}" $K "$PRO:$L/$f" "$A:$D/$f" || log "root $f FAILED"; done
log "root files on alpha"
t0=$(date +%s)
for f in stage.xml stage.bin; do scp -3 -q "${S[@]}" $K "$PRO:$L/stage0/$f" "$A:$D/stage0/$f" || log "stage0/$f FAILED"; done
log "stage0 copied in $(( $(date +%s)-t0 ))s"
./wps.sh alpha <(printf "'alpha manifest=' + (Get-FileHash C:\\\\ecgbench\\\\shards\\\\q122-sym-3\\\\manifest.json).Hash.Substring(0,16) + ' stage0MB=' + [math]::Round((Get-ChildItem C:\\\\ecgbench\\\\shards\\\\q122-sym-3\\\\stage0 -File | Measure-Object Length -Sum).Sum/1MB) + ' free GB=' + [math]::Round((Get-PSDrive C).Free/1GB,1)\n") | grep -v '^Warning'
echo "STAGE0_ALPHA_DONE" | tee ../probe/stage0_alpha.done
