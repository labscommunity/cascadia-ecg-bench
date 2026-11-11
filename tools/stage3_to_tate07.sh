#!/bin/bash
# wait for pro:~/q122-sym-stages-4/stage3 (+root) to be complete, then stream it to tate-07 through this Mac (bastion alias, tailnet fallback)
cd "$(dirname "$0")"
S=(-o ConnectTimeout=20 -o BatchMode=yes -o LogLevel=ERROR -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null)
PRO=tatef@192.168.0.213; L=/Users/tatef/q122-sym-stages-4; K="-i $HOME/.ssh/id_ed25519"
log(){ echo "[$(date +%H:%M:%S)] [s3] $*"; }
until ssh "${S[@]}" $PRO "test \$(du -sm $L/stage3 | cut -f1) -ge 26350 && ! ls $L/stage3/.stage.bin.* >/dev/null 2>&1 && ! pgrep -f 'rsync -a --partial' >/dev/null" 2>/dev/null; do sleep 60; done
log "stage3 complete on pro: $(ssh "${S[@]}" $PRO "du -sm $L/stage3 | cut -f1") MB"
ROOT="chat_template.jinja config.json generation_config.json manifest.json openvino_text_embeddings_model.bin openvino_text_embeddings_model.xml tokenizer.json"
D=C:/ecgbench/shards/q122-sym-4
for f in $ROOT; do scp -3 -q "${S[@]}" $K "$PRO:$L/$f" "cascadia-tate-07:$D/$f" || scp -3 -q "${S[@]}" $K "$PRO:$L/$f" "cascadia-tate-07-ts:$D/$f" || log "root $f FAILED"; done
log "root files on tate-07"
t0=$(date +%s)
if scp -3 "${S[@]}" $K -r "$PRO:$L/stage3" "cascadia-tate-07:$D/" 2>&1 | tail -2; then log "stage3 on tate-07 via bastion in $(( $(date +%s)-t0 ))s"; else log "bastion copy failed, retry via tailnet"; scp -3 "${S[@]}" $K -r "$PRO:$L/stage3" "cascadia-tate-07-ts:$D/" 2>&1 | tail -2 && log "stage3 on tate-07 via tailnet in $(( $(date +%s)-t0 ))s"; fi
./wps.sh tate07 <(printf "'tate07 manifest=' + (Get-FileHash C:\\\\ecgbench\\\\shards\\\\q122-sym-4\\\\manifest.json).Hash.Substring(0,16) + ' stage3MB=' + [math]::Round((Get-ChildItem C:\\\\ecgbench\\\\shards\\\\q122-sym-4\\\\stage3 -Recurse -File | Measure-Object Length -Sum).Sum/1MB)\n") | tail -1
echo "STAGE3_TATE07_DONE" | tee ../probe/stage3_tate07.done
