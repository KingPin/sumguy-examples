#!/usr/bin/env bash
# Usage: ./jitter.sh 192.168.1.50 [count]
# Sends one probe every 0.2 s and reports percentiles in ms.
host="${1:?usage: jitter.sh HOST [COUNT]}"
count="${2:-200}"

ping -c "$count" -i 0.2 "$host" \
  | grep -oE 'time=[0-9.]+' | cut -d= -f2 | sort -n \
  | awk -v sent="$count" '
    { v[NR] = $1 }
    END {
      if (NR == 0) { print "no replies"; exit 1 }
      p50 = v[int((NR * 0.50) + 0.5)]
      p95 = v[int((NR * 0.95) + 0.5)]
      printf "samples=%d loss=%.1f%% p50=%.1f ms p95=%.1f ms max=%.1f ms\n",
             NR, (sent - NR) * 100 / sent, p50, p95, v[NR]
    }'
