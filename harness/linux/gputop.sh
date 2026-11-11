#!/bin/bash
# intel_gpu_top JSON samples (engine busy %, power if available) for <seconds>. usage: gputop.sh <out.json> <seconds>
OUT=$1; SECS=${2:-120}
sudo -n timeout $SECS intel_gpu_top -J -s 1000 > $OUT 2>/dev/null
