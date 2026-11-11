#!/bin/bash
# charlie -> alpha: 2-stage stage0 + 3-stage stage0 (+ root files); charlie -> beta: 3-stage stage1 (+ root files). Relay through the Mac (scp -3) over the LAN.
S="-o ConnectTimeout=15 -o BatchMode=yes -o LogLevel=ERROR -o StrictHostKeyChecking=accept-new -i $HOME/.ssh/id_ed25519"
C=tatef@192.168.0.188; A=tatef@192.168.0.101; B=tatef@192.168.0.103
mk() { ssh $S $1 "powershell -NoProfile -Command \"New-Item -ItemType Directory -Force -Path $2 | Out-Null\""; }
t0=$(date +%s)
mk $A 'C:\ecgbench\shards\q36-2stage'; mk $A 'C:\ecgbench\shards\q36-3stage'; mk $B 'C:\ecgbench\shards\q36-3stage'
for tree in q36-2stage q36-3stage; do
  for f in manifest.json config.json generation_config.json chat_template.jinja tokenizer.json openvino_text_embeddings_model.xml openvino_text_embeddings_model.bin; do
    scp -3 -q $S "$C:C:/ecgbench/shards/$tree/$f" "$A:C:/ecgbench/shards/$tree/$f"
    [ $tree = q36-3stage ] && scp -3 -q $S "$C:C:/ecgbench/shards/$tree/$f" "$B:C:/ecgbench/shards/$tree/$f"
  done
done
echo "root files copied in $(( $(date +%s)-t0 ))s"
scp -3 -q -r $S "$C:C:/ecgbench/shards/q36-2stage/stage0" "$A:C:/ecgbench/shards/q36-2stage/" && echo "alpha 2stage/stage0 done $(( $(date +%s)-t0 ))s"
scp -3 -q -r $S "$C:C:/ecgbench/shards/q36-3stage/stage0" "$A:C:/ecgbench/shards/q36-3stage/" && echo "alpha 3stage/stage0 done $(( $(date +%s)-t0 ))s"
scp -3 -q -r $S "$C:C:/ecgbench/shards/q36-3stage/stage1" "$B:C:/ecgbench/shards/q36-3stage/" && echo "beta 3stage/stage1 done $(( $(date +%s)-t0 ))s"
for t in "$A" "$B"; do ssh $S $t "powershell -NoProfile -Command \"Get-ChildItem C:\ecgbench\shards -Recurse -Directory | % { 'DIR=' + \$_.FullName + ' ' + [math]::Round((Get-ChildItem \$_.FullName -Recurse -File | Measure-Object Length -Sum).Sum/1GB,2) + 'GB' }; 'FREE_GB=' + [math]::Round((Get-PSDrive C).Free/1GB,1); (Get-FileHash C:\ecgbench\shards\q36-3stage\manifest.json).Hash\""; done
ssh $S $C "powershell -NoProfile -Command \"(Get-FileHash C:\ecgbench\shards\q36-3stage\manifest.json).Hash; (Get-FileHash C:\ecgbench\shards\q36-2stage\manifest.json).Hash\""
echo "COPY_DONE $(( $(date +%s)-t0 ))s"
