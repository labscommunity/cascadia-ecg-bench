#!/bin/bash
# VM -> pro (stage1) then pro -> beta, file by file
cd "$(dirname "$0")"
S=(-o ConnectTimeout=20 -o BatchMode=yes -o LogLevel=ERROR -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null); K="-i $HOME/.ssh/id_ed25519"
log(){ echo "[$(date +%H:%M:%S)] [s1] $*"; }
t0=$(date +%s)
ssh "${S[@]}" tatef@192.168.0.213 "rsync -av --partial -e 'ssh -p 2222 -o BatchMode=yes' tatef@127.0.0.1:/data/models/q122-sym-stages-4/stage1/ ~/q122-sym-stages-4/stage1/ > ~/q122s4_stage1.log 2>&1; ls -l ~/q122-sym-stages-4/stage1/ | awk '{print \$5, \$9}'" | grep -v "^ *$"
log "stage1 on pro in $(( $(date +%s)-t0 ))s"
./wps.sh beta <(printf "New-Item -ItemType Directory -Force -Path C:\\\\ecgbench\\\\shards\\\\q122-sym-4\\\\stage1 | Out-Null; 'ok'\n") | tail -1
t1=$(date +%s)
for f in stage.xml stage.bin; do scp -3 "${S[@]}" $K "tatef@192.168.0.213:/Users/tatef/q122-sym-stages-4/stage1/$f" "tatef@192.168.0.103:C:/ecgbench/shards/q122-sym-4/stage1/$f" 2>&1 | tail -1; done
log "beta stage1 in $(( $(date +%s)-t1 ))s: $(./wps.sh beta <(printf "'MB=' + [math]::Round((Get-ChildItem C:\\\\ecgbench\\\\shards\\\\q122-sym-4\\\\stage1 -File | Measure-Object Length -Sum).Sum/1MB)\n") | tail -1)"
echo BETA_STAGE1_DONE
