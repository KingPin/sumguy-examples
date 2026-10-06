#!/usr/bin/env bash
# zstd vs lz4 vs gzip vs xz vs bzip2 on four public data sets.
# Usage: ./bench.sh   (run ./fetch_data.sh first)
# Env: RUNS (3), CPUS (4-7), ONE_CPU (4), CONFIGS ("all" or names from run.sh), DATASETS, OUT
set -euo pipefail
cd "$(dirname "$0")"

# CPU pinning. Check `lscpu -e=CPU,CORE` and pick 4 CPUs on 4 different physical cores.
# Default layout: 8-core/16-thread CPU where CPU n and n+8 share a core, so 12-15 stay idle.
CPUS=${CPUS:-4-7}
ONE_CPU=${ONE_CPU:-4}
OUT=${OUT:-results}
IMG=compression-bench

mkdir -p "$OUT"
docker build -q -t $IMG . >/dev/null

{ echo "date: $(date -u +%FT%TZ)"; echo "kernel: $(uname -r)"; lscpu | grep 'Model name';
  echo "governor: $(cat /sys/devices/system/cpu/cpu${ONE_CPU}/cpufreq/scaling_governor 2>/dev/null || echo n/a)"
  echo "os: $(. /etc/os-release && echo "$PRETTY_NAME")"; echo "docker: $(docker version -f '{{.Server.Version}}')";
  echo "cpus: $CPUS one_cpu: $ONE_CPU runs: ${RUNS:-3}"; free -g | head -2; lscpu -e=CPU,CORE
  docker run --rm --entrypoint bash $IMG -c 'zstd --version; lz4 --version; xz --version | head -1;
    gzip --version | head -1; pigz --version 2>&1; bzip2 --help 2>&1 | head -1'
  (cd data && sha256sum *); } > "$OUT/env.txt"

# Inputs and outputs live in tmpfs, so disk speed never enters the numbers.
docker run --rm --cpuset-cpus "$CPUS" --tmpfs /work:size=1g \
  -e RUNS -e ONE_CPU="$ONE_CPU" -e CONFIGS -e DATASETS \
  -v "$PWD/data:/data:ro" -v "$PWD/$OUT:/out" $IMG
echo "done. run: python3 summarize.py $OUT"
