# Runs inside the container. Inputs in /data (read-only), scratch in /work (tmpfs).
# Writes one CSV row per run to /out/results.csv.
set -euo pipefail
RUNS=${RUNS:-3}
ONE=${ONE_CPU:-4}            # single-thread configs are pinned to this CPU
CONFIGS=${CONFIGS:-all}
DATASETS=${DATASETS:-logs dbdump rootfs video}

# name | threads | compress | decompress
# Thread counts are always explicit: xz 5.6+ and lz4 1.10 default to all cores.
TABLE='
gzip-1          |1| gzip -1 -c                    | gzip -d -c
gzip-6          |1| gzip -6 -c                    | gzip -d -c
gzip-9          |1| gzip -9 -c                    | gzip -d -c
pigz-6-T4       |4| pigz -6 -p 4 -c               | pigz -d -p 4 -c
bzip2-9         |1| bzip2 -9 -c                   | bzip2 -d -c
lz4-1           |1| lz4 -1 -T1 -c                 | lz4 -d -c
lz4-9           |1| lz4 -9 -T1 -c                 | lz4 -d -c
lz4-1-T4        |4| lz4 -1 -T4 -c                 | lz4 -d -c
zstd-1          |1| zstd -1 -T1 -c                | zstd -d -c
zstd-3          |1| zstd -3 -T1 -c                | zstd -d -c
zstd-9          |1| zstd -9 -T1 -c                | zstd -d -c
zstd-19         |1| zstd -19 -T1 -c               | zstd -d -c
zstd-3-T4       |4| zstd -3 -T4 -c                | zstd -d -c
zstd-19-T4      |4| zstd -19 -T4 -c               | zstd -d -c
zstd-19-long-T4 |4| zstd -19 --long=27 -T4 -c     | zstd -d --long=27 -c
xz-0            |1| xz -0 -T1 -c                  | xz -d -T1 -c
xz-6            |1| xz -6 -T1 -c                  | xz -d -T1 -c
xz-9            |1| xz -9 -T1 -c                  | xz -d -T1 -c
xz-6-T4         |4| xz -6 -T4 -c                  | xz -d -T4 -c
'

ns() { date +%s%N; }
# $1 = cpu list, $2 = input, $3 = output, rest = command. Prints "seconds peak_rss_kib".
timed() {
  local cpus=$1 in=$2 out=$3; shift 3
  local t0 t1; t0=$(ns)
  taskset -c "$cpus" /usr/bin/time -f %M -o /work/rss "$@" < "$in" > "$out"
  t1=$(ns)
  echo "$(( (t1 - t0) / 1000 )) $(cat /work/rss)" | awk '{printf "%.4f %d\n", $1/1e6, $2}'
}

[ -f /out/results.csv ] || echo "dataset,config,threads,run,in_bytes,out_bytes,comp_s,comp_rss_kib,decomp_s,decomp_rss_kib" > /out/results.csv

for d in $DATASETS; do
  cp "/data/$d" /work/in
  in_bytes=$(stat -c %s /work/in)
  echo "$TABLE" | while IFS='|' read -r name thr comp decomp; do
    name=$(echo $name); [ -n "$name" ] || continue
    [ "$CONFIGS" = all ] || [[ " $CONFIGS " == *" $name "* ]] || continue
    cpus=$ONE; [ "$thr" -eq 1 ] || cpus=$(taskset -cp $$ | awk '{print $NF}')
    for r in $(seq 1 "$RUNS"); do
      read -r cs crss < <(timed "$cpus" /work/in /work/out.z $comp)
      read -r ds drss < <(timed "$cpus" /work/out.z /dev/null $decomp)
      out_bytes=$(stat -c %s /work/out.z)
      if [ "$r" = 1 ]; then   # round-trip check, not timed
        $decomp < /work/out.z | cmp -s - /work/in || { echo "ROUND-TRIP FAILED: $d $name" >&2; exit 1; }
      fi
      echo "$d,$name,$thr,$r,$in_bytes,$out_bytes,$cs,$crss,$ds,$drss" >> /out/results.csv
      printf '%-7s %-16s run %s  ratio %6.3f  comp %8.2fs  decomp %6.2fs\n' "$d" "$name" "$r" \
        "$(awk -v a=$in_bytes -v b=$out_bytes 'BEGIN{print a/b}')" "$cs" "$ds"
    done
  done
  rm -f /work/in /work/out.z
done
