#!/usr/bin/awk -f
# Usage: awk -F, -f avg_power.awk nas.csv
NR > 1 {
  dt = $1 - pt
  if (dt > 0 && dt < 300) { wh += pw * dt / 3600; secs += dt }
}
{ pt = $1; pw = $2 }
END {
  if (secs > 0) printf "avg %.1f W over %.1f h, %.3f kWh/day\n", wh / (secs / 3600), secs / 3600, wh / (secs / 3600) * 24 / 1000
}