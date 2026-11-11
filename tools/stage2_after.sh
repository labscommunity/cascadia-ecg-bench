#!/bin/bash
cd "$(dirname "$0")"
until grep -q "stage3 complete on pro" ../probe/stage3_tate07.out 2>/dev/null; do sleep 60; done
ssh -o ConnectTimeout=15 -o BatchMode=yes tatef@192.168.0.213 "rsync -av --partial -e 'ssh -p 2222 -o BatchMode=yes' tatef@127.0.0.1:/data/models/q122-sym-stages-4/stage2/ ~/q122-sym-stages-4/stage2/ > ~/q122s4_stage2.log 2>&1; du -sm ~/q122-sym-stages-4/stage2"
echo "[$(date +%H:%M:%S)] [s2] stage2 copy finished"
