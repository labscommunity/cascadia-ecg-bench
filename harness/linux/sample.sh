#!/bin/bash
# Linux utilization + RAPL power sampler -> JSONL (1 line/s). usage: sample.sh <out.jsonl> <seconds> [proc-regex]
OUT=$1; SECS=${2:-120}; PM=${3:-cascadia}
E0=/sys/class/powercap/intel-rapl:0/energy_uj
read_e() { sudo -n cat $E0 2>/dev/null || cat $E0 2>/dev/null; }
read_cpu() { awk '/^cpu /{print $2+$3+$4+$6+$7+$8, $5}' /proc/stat; }
e_prev=$(read_e); read b_prev i_prev <<<"$(read_cpu)"; t_prev=$(date +%s.%N)
end=$(( $(date +%s) + SECS ))
while [ $(date +%s) -lt $end ]; do
  sleep 1
  e=$(read_e); read b i <<<"$(read_cpu)"; t=$(date +%s.%N)
  dt=$(echo "$t - $t_prev" | bc -l); de=$(( e - e_prev )); [ $de -lt 0 ] && de=0
  w=$(echo "scale=3; $de / 1000000 / $dt" | bc -l)
  db=$(( b - b_prev )); di=$(( i - i_prev )); cpu=$(echo "scale=1; 100 * $db / ($db + $di + 0.0001)" | bc -l)
  avail=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo); tot=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
  rss=$(ps -C cascadia -o rss= 2>/dev/null | awk '{s+=$1} END{print int(s/1024)}'); [ -z "$rss" ] && rss=0
  gpu=$(cat /sys/class/drm/card0/device/gt/gt0/rps_cur_freq_mhz 2>/dev/null || cat /sys/class/drm/card0/gt_cur_freq_mhz 2>/dev/null || echo null)
  echo "{\"ts\":$t,\"host\":\"$(hostname)\",\"pkg_w\":$w,\"cpu_util_pct\":$cpu,\"mem_avail_mb\":$avail,\"mem_total_mb\":$tot,\"proc_rss_mb\":$rss,\"gpu_mhz\":$gpu}" >> $OUT
  e_prev=$e; b_prev=$b; i_prev=$i; t_prev=$t
done
