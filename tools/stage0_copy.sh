#!/bin/bash
cd "$(dirname "$0")"
S=(-o ConnectTimeout=20 -o BatchMode=yes -o LogLevel=ERROR -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null)
t0=$(date +%s)
scp -3 "${S[@]}" -i "$HOME/.ssh/id_ed25519" -r "cascadia-tate-07:C:/ecgbench/shards/q36-2stage/stage0" "tatef@192.168.0.101:C:/ecgbench/shards/q36-2stage/" 2>&1; rc=$?
echo "[$(date +%H:%M:%S)] stage0 scp rc=$rc in $(( $(date +%s)-t0 ))s"
echo "STAGE0_COPY_DONE rc=$rc"
