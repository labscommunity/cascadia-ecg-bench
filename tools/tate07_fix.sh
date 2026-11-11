#!/bin/bash
cd "$(dirname "$0")"; source ./hosts.sh
S=(-o ConnectTimeout=20 -o BatchMode=yes -o LogLevel=ERROR -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null)
log(){ echo "[$(date +%H:%M:%S)] [s3] $*"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
while pgrep -f "scp -3 .*stage3" >/dev/null; do sleep 30; done; log "stage3 scp to tate-07 exited"
ps tate07 "New-Item -ItemType Directory -Force -Path C:\ecgbench\shards\q122-sym-4\stage3 | Out-Null; Move-Item -Force C:\ecgbench\shards\q122-sym-4\stage.bin, C:\ecgbench\shards\q122-sym-4\stage.xml C:\ecgbench\shards\q122-sym-4\stage3\ -ErrorAction SilentlyContinue; 'stage3 bytes=' + ((Get-ChildItem C:\ecgbench\shards\q122-sym-4\stage3 -File | % { \$_.Name + '=' + \$_.Length }) -join ' ')" | tail -1
for f in chat_template.jinja config.json generation_config.json manifest.json openvino_text_embeddings_model.bin openvino_text_embeddings_model.xml tokenizer.json; do
  scp -3 -q "${S[@]}" -i "$HOME/.ssh/id_ed25519" "tatef@192.168.0.213:/Users/tatef/q122-sym-stages-4/$f" "cascadia-tate-07-ts:C:/ecgbench/shards/q122-sym-4/$f" || log "root $f FAILED"
done
V=$(ps tate07 "'tate07 manifest=' + (Get-FileHash C:\ecgbench\shards\q122-sym-4\manifest.json).Hash.Substring(0,16) + ' stage3MB=' + [math]::Round((Get-ChildItem C:\ecgbench\shards\q122-sym-4\stage3 -Recurse -File | Measure-Object Length -Sum).Sum/1MB) + ' files=' + (Get-ChildItem C:\ecgbench\shards\q122-sym-4 -File).Count" | tail -1); log "$V"
if echo "$V" | grep -qi "manifest=8caabfd79f413639" && echo "$V" | grep -qE "stage3MB=263[0-9][0-9]"; then echo "STAGE3_TATE07_DONE" | tee ../probe/stage3_tate07.done; else log "tate-07 tree NOT OK; not releasing"; fi
