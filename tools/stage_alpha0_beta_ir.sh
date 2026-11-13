#!/bin/bash
# re-stage: 122B stage0 (+root) on alpha from pro; 35B IR on beta (next to its stage1) for whole-model tests
cd "$(dirname "$0")"; source ./hosts.sh
S=(-o ConnectTimeout=20 -o BatchMode=yes -o LogLevel=ERROR -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null); K="-i $HOME/.ssh/id_ed25519"
PRO=tatef@192.168.0.213; L=/Users/tatef/q122-sym-stages-3; A=tatef@192.168.0.101; D=C:/ecgbench/shards/q122-sym-3
log(){ echo "[$(date +%H:%M:%S)] [stage] $*"; }
ps() { local f; f=$(mktemp); printf '%s\n' "$2" > "$f"; ./wps.sh "$1" "$f"; rm -f "$f"; }
./wbg.sh beta 'C:\ecgbench\results\dl35b_beta.log' 'set HF_HUB_DISABLE_XET=1 && set HF_HUB_DISABLE_PROGRESS_BARS=1 && C:\ecgbench\venv\Scripts\hf.exe download OpenVINO/Qwen3.6-35B-A3B-int4-ov --local-dir C:\ecgbench\models\Qwen3.6-35B-A3B-int4-ov' | tail -1
ps alpha "New-Item -ItemType Directory -Force -Path C:\ecgbench\shards\q122-sym-3\stage0 | Out-Null; 'alpha free GB=' + [math]::Round((Get-PSDrive C).Free/1GB,1)" | tail -1
t0=$(date +%s); for f in chat_template.jinja config.json generation_config.json manifest.json openvino_text_embeddings_model.bin openvino_text_embeddings_model.xml tokenizer.json; do scp -3 -q "${S[@]}" $K "$PRO:$L/$f" "$A:$D/$f"; done
for f in stage.xml stage.bin; do scp -3 -q "${S[@]}" $K "$PRO:$L/stage0/$f" "$A:$D/stage0/$f"; done
log "alpha stage0: $(ps alpha "(Get-Item C:\ecgbench\shards\q122-sym-3\stage0\stage.bin).Length" | tail -1) bytes in $(( $(date +%s)-t0 ))s"
until ps beta "((Get-Process hf -ErrorAction SilentlyContinue).Count -eq 0) -and (Test-Path C:\ecgbench\models\Qwen3.6-35B-A3B-int4-ov\openvino_language_model.bin)" | tail -1 | grep -q True; do sleep 30; done
log "beta 35B IR: $(ps beta "[math]::Round((Get-ChildItem C:\ecgbench\models\Qwen3.6-35B-A3B-int4-ov -Recurse -File | Measure-Object Length -Sum).Sum/1MB)" | tail -1) MB; free: $(ps beta "[math]::Round((Get-PSDrive C).Free/1GB,1)" | tail -1) GB"
echo STAGE_DONE
