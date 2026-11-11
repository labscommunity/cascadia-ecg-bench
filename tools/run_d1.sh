#!/bin/bash
# D1: Qwen3.5-122B-A10B int4, 2-stage pipeline: rank 1 on tate-08 (Linux, stage1 + lm_head), rank 0 on tate-07 (Windows, stage0 + embeddings, API).
set -u; cd "$(dirname "$0")"; source ./hosts.sh
label=${1:-D1-122b-2x64gb}; OUT="/Users/tatef/Workspaces/cascadia-ecg-bench/results/$label"; mkdir -p "$OUT"
S8=(ssh "${SSHOPTS[@]}" -o UserKnownHostsFile=/dev/null cascadia-tate-08)
log(){ echo "[$(date +%H:%M:%S)] [D1] $*" | tee -a "$OUT/orchestrator.log"; }
log "pause tate-08 SWE node (restore: systemd-run --unit=swe-node ... see memory note)"
"${S8[@]}" 'sudo -n systemctl stop swe-node.service 2>&1; sleep 3; pgrep -a ovms | wc -l; free -g | sed -n 2p' | tee -a "$OUT/orchestrator.log"
log "launch rank 1 on tate-08"
"${S8[@]}" 'mkdir -p ~/ecgbench/results/'"$label"'; cd ~/ecgbench && setsid nohup ./rt/cascadia worker --rank 1 --total 2 --model ~/ecgbench/shards/q122-2stage --engine qwen35 --device GPU --listen :9100 --ov-cache-dir "" --prefix-cache-gb 0 < /dev/null > ~/ecgbench/results/'"$label"'/rank1.log 2>&1 & sleep 2; pgrep -af "cascadia worker" | grep -v pgrep | cut -c1-160'
sleep 20
log "launch rank 0 on tate-07 (API :8130, next = tate-08 tailnet :9100)"
./wps.sh tate07 <(printf "& 'C:\\\\ecgbench\\\\harness\\\\win\\\\server.ps1' -Mode worker -Model 'C:\\\\ecgbench\\\\shards\\\\q122-2stage' -Engine qwen35 -Device GPU -Rank 0 -Total 2 -Next 100.79.46.111:9100 -Api ':8130' -CacheDir none -Extra '--prefix-cache-gb 0' -Log 'C:\\\\ecgbench\\\\results\\\\$label\\\\rank0.log'\n") | tee -a "$OUT/orchestrator.log"
# standard measurement sequence on the head (server already up); long health timeout for the 32 GB compile
NOLAUNCH=1 NOSTOP=1 HEALTH_TIMEOUT=2400 TAGS="config=D1-122b-2shard-2x64gb model=q35-122b stages=2" ./run_config.sh tate07 "$label"
log "rank-1 side: Linux sampler + intel_gpu_top during a second steady loop"
"${S8[@]}" 'cd ~/ecgbench && (setsid nohup bash harness/linux/sample.sh ~/ecgbench/results/'"$label"'/steady-rank1.util.jsonl 95 < /dev/null > /dev/null 2>&1 &); (setsid nohup bash harness/linux/gputop.sh ~/ecgbench/results/'"$label"'/steady-rank1.gputop.json 90 < /dev/null > /dev/null 2>&1 &); echo samplers-started'
./wps.sh tate07 <(printf "& 'C:\\\\ecgbench\\\\harness\\\\win\\\\launch.ps1' -Cmd '\"C:\\\\ecgbench\\\\venv\\\\Scripts\\\\python.exe\" C:\\\\ecgbench\\\\harness\\\\bench_client.py --base http://127.0.0.1:8130 --mode steady --seconds 90 --steady-prompt medium --max-tokens 128 --out C:\\\\ecgbench\\\\results\\\\$label\\\\steady2.jsonl --tag config=D1 --tag stages=2' -Log 'C:\\\\ecgbench\\\\results\\\\$label\\\\steady2-client.log' -Priority Normal\n") >/dev/null
sleep 100
log "GSM8K-40 eval on the 122B chain"; TAGS="config=D1-122b-2shard-2x64gb stages=2 model=q35-122b" EVAL_TOKENS=400 EVAL_WAIT_MIN=150 ./run_eval.sh tate07 "$label-eval"
log "stop ranks"
./wps.sh tate07 <(printf "& 'C:\\\\ecgbench\\\\harness\\\\win\\\\stop.ps1' -Match 'cascadia.exe'\n") | tail -1 | tee -a "$OUT/orchestrator.log"
"${S8[@]}" 'pkill -f "cascadia worker"; sleep 2; pgrep -af "cascadia worker" | grep -v pgrep | wc -l'
log "collect rank-1 artifacts"
mkdir -p "$OUT/rank1-tate08"; scp -q "${SSHOPTS[@]}" -o UserKnownHostsFile=/dev/null -r "cascadia-tate-08:~/ecgbench/results/$label/*" "$OUT/rank1-tate08/" 2>&1 | tail -1
echo DONE > "$OUT/STATUS"; log "done (restore of the SWE node is a separate step)"
