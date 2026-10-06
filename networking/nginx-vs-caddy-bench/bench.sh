#!/usr/bin/env bash
# nginx vs Caddy on one box, with CPU pinning.
# Usage: ./bench.sh [duration_seconds] [runs]
# Env: SERVERS="nginx nginx-upstream nginx-keepalive caddy caddy-keepalive", NGINX_IMAGE, OUT, *_CPUS
set -euo pipefail
cd "$(dirname "$0")"

DUR=${1:-20}
RUNS=${2:-3}
CONC=100
FIXED_QPS=5000

# CPU pinning. Check `lscpu -e=CPU,CORE` on your box and adjust.
# Default layout: 8-core/16-thread CPU where CPU n and n+8 share a core.
SERVER_CPUS=${SERVER_CPUS:-2,3}           # 2 physical cores; siblings 10,11 left idle
LOADGEN_CPUS=${LOADGEN_CPUS:-6,7,14,15,1,9}  # 3 physical cores
BACKEND_CPUS=${BACKEND_CPUS:-4,5,12,13}       # 2 physical cores

NGINX_IMAGE=${NGINX_IMAGE:-nginx:1.31.6-alpine}
CADDY_IMAGE=${CADDY_IMAGE:-caddy:2.11.6-alpine}
OHA_IMAGE=${OHA_IMAGE:-ghcr.io/hatoo/oha:1.16.0}
WHOAMI_IMAGE=${WHOAMI_IMAGE:-traefik/whoami:v1.11.0}
NET=benchnet
OUT=${OUT:-results}
SERVERS=${SERVERS:-nginx nginx-upstream caddy caddy-keepalive}

mkdir -p certs www "$OUT"

# 1 KB static page and a self-signed ECDSA P-256 cert shared by both servers.
[ -f www/index.html ] || { printf '<!doctype html><title>bench</title><pre>\n'; head -c 960 /dev/zero | tr '\0' 'x'; printf '\n</pre>\n'; } > www/index.html
[ -f www/big.bin ] || head -c 102400 /dev/urandom > www/big.bin   # 100 KB, incompressible
[ -f certs/cert.pem ] || docker run --rm -v "$PWD/certs:/c" alpine:3.22 sh -c \
  'apk add -q openssl && openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -days 30 \
   -subj /CN=bench.lab -addext subjectAltName=DNS:bench.lab -keyout /c/key.pem -out /c/cert.pem 2>/dev/null && chmod 644 /c/*.pem'

docker network inspect $NET >/dev/null 2>&1 || docker network create $NET >/dev/null

cg() { echo "/sys/fs/cgroup/system.slice/docker-$(docker inspect -f '{{.Id}}' "$1").scope"; }
cpu_usec() { awk '/usage_usec/{print $2}' "$(cg "$1")/cpu.stat"; }
mem_now()  { cat "$(cg "$1")/memory.current"; }
mem_peak() { cat "$(cg "$1")/memory.peak"; }

cleanup() { docker rm -f bench-server bench-whoami bench-oha >/dev/null 2>&1 || true; }
trap cleanup EXIT

start_server() {  # $1 = nginx | nginx-upstream | nginx-keepalive | caddy | caddy-keepalive
  cleanup
  docker run -d --name bench-whoami --network $NET --network-alias whoami \
    --cpuset-cpus "$BACKEND_CPUS" "$WHOAMI_IMAGE" >/dev/null
  local common=(-d --name bench-server --network $NET --network-alias bench.lab
    --cpuset-cpus "$SERVER_CPUS" -v "$PWD/www:/srv/www:ro" -v "$PWD/certs:/certs:ro")
  case $1 in
    nginx)       docker run "${common[@]}" -v "$PWD/configs/nginx.conf:/etc/nginx/nginx.conf:ro" "$NGINX_IMAGE" >/dev/null ;;
    nginx-upstream|nginx-keepalive)
                 docker run "${common[@]}" -v "$PWD/configs/$1.conf:/etc/nginx/nginx.conf:ro" "$NGINX_IMAGE" >/dev/null ;;
    caddy)       docker run "${common[@]}" -v "$PWD/configs/Caddyfile:/etc/caddy/Caddyfile:ro" "$CADDY_IMAGE" >/dev/null ;;
    caddy-keepalive)
                 docker run "${common[@]}" -v "$PWD/configs/Caddyfile-keepalive:/etc/caddy/Caddyfile:ro" "$CADDY_IMAGE" >/dev/null ;;
  esac
  sleep 5
}

oha() {  # extra oha args; JSON to stdout. Samples load-generator CPU mid-run into $OUT/.loadgen
  docker rm -f bench-oha >/dev/null 2>&1 || true
  docker run -d --name bench-oha --network $NET --cpuset-cpus "$LOADGEN_CPUS" \
    "$OHA_IMAGE" --no-tui --output-format json --insecure "$@" >/dev/null
  sleep 2
  local a b
  a=$(cpu_usec bench-oha 2>/dev/null || echo 0); sleep 2; b=$(cpu_usec bench-oha 2>/dev/null || echo 0)
  awk -v a="$a" -v b="$b" 'BEGIN{printf "%.2f", (b-a)/2000000}' > "$OUT/.loadgen"
  docker wait bench-oha >/dev/null
  docker logs bench-oha 2>/dev/null
  docker rm bench-oha >/dev/null
}

measure() {  # $1 server label, $2 scenario, $3 run, rest = oha args
  local s=$1 sc=$2 r=$3; shift 3
  local f="$OUT/$s/$sc-$r.json"
  # Fresh containers per test: a new network namespace, so TIME_WAIT sockets
  # left by one test cannot starve the next one of local ports.
  start_server "$s"
  oha -z 3s -c $CONC https://bench.lab/ >/dev/null   # warm-up on the static path
  local c0 b0 t0 c1 b1 t1
  c0=$(cpu_usec bench-server); b0=$(cpu_usec bench-whoami); t0=$(date +%s%N)
  oha "$@" > "$f.oha"
  c1=$(cpu_usec bench-server); b1=$(cpu_usec bench-whoami); t1=$(date +%s%N)
  python3 - "$f" "$f.oha" "$c0" "$c1" "$b0" "$b1" "$t0" "$t1" "$(mem_now bench-server)" "$OUT/.loadgen" <<'PY'
import json, sys
f, o, c0, c1, b0, b1, t0, t1, mem = sys.argv[1:10]
wall = (int(t1) - int(t0)) / 1e9
d = json.load(open(o))
d["_host"] = {
    "server_cores": (int(c1) - int(c0)) / 1e6 / wall,
    "backend_cores": (int(b1) - int(b0)) / 1e6 / wall,
    "server_mem_bytes_end": int(mem),
    "loadgen_cores": float(open(sys.argv[10]).read() or 0),
}
json.dump(d, open(f, "w"))
PY
  rm -f "$f.oha"
  local peak; peak=$(mem_peak bench-server)
  [ "$peak" -gt "$(cat "$OUT/$s/peak_mem_bytes" 2>/dev/null || echo 0)" ] && echo "$peak" > "$OUT/$s/peak_mem_bytes"
  echo "  $s $sc run $r done"
}

for s in $SERVERS; do
  mkdir -p "$OUT/$s"
  start_server "$s"
  echo "$s: workers=$(docker top bench-server -o pid,comm | tail -n +2 | wc -l) procs, idle mem=$(mem_now bench-server)"
  mem_now bench-server > "$OUT/$s/idle_mem_bytes"

  for r in $(seq 1 "$RUNS"); do
    if [[ $s == nginx || $s == caddy ]]; then   # the other configs only change the proxy path
      measure "$s" static-http   "$r" -z "${DUR}s" -c $CONC http://bench.lab/
      measure "$s" static-https  "$r" -z "${DUR}s" -c $CONC https://bench.lab/
      measure "$s" big-http      "$r" -z "${DUR}s" -c $CONC http://bench.lab/big.bin
      measure "$s" big-https     "$r" -z "${DUR}s" -c $CONC https://bench.lab/big.bin
      measure "$s" newconn-https "$r" -z "${DUR}s" -c $CONC --disable-keepalive https://bench.lab/
    fi
    measure "$s" proxy-https "$r" -z "${DUR}s" -c $CONC https://bench.lab/proxy/
    measure "$s" proxy-fixed "$r" -z "${DUR}s" -c $CONC -q $FIXED_QPS --latency-correction https://bench.lab/proxy/
  done
done

{ echo "date: $(date -u +%FT%TZ)"; echo "kernel: $(uname -r)"; lscpu | grep 'Model name';
  echo "os: $(. /etc/os-release && echo "$PRETTY_NAME")"; echo "docker: $(docker version -f '{{.Server.Version}}')";
  echo "nginx: $NGINX_IMAGE"; echo "caddy: $CADDY_IMAGE"; echo "oha: $OHA_IMAGE"; echo "whoami: $WHOAMI_IMAGE";
  echo "server_cpus: $SERVER_CPUS loadgen_cpus: $LOADGEN_CPUS backend_cpus: $BACKEND_CPUS";
  echo "duration: ${DUR}s runs: $RUNS concurrency: $CONC fixed_qps: $FIXED_QPS"; } > "$OUT/env.txt"
if [ "${SUSTAINED:-1}" = 1 ]; then
  # 90 s at full load through the proxy, once per config, sampling TIME_WAIT every 20 s.
  # 20 s tests are too short to show a slow port leak; this one is not.
  for s in $SERVERS; do
    mkdir -p "$OUT/$s"
    start_server "$s"
    docker rm -f bench-oha >/dev/null 2>&1 || true
    docker run -d --name bench-oha --network $NET --cpuset-cpus "$LOADGEN_CPUS" "$OHA_IMAGE" \
      --no-tui --output-format json --insecure -z 90s -c $CONC https://bench.lab/proxy/ >/dev/null
    tw=""
    for _ in 1 2 3 4; do
      sleep 20
      tw="$tw $(cat /proc/$(docker inspect -f '{{.State.Pid}}' bench-server)/net/tcp{,6} | awk '$4=="06"' | wc -l)"
    done
    docker wait bench-oha >/dev/null
    docker logs bench-oha > "$OUT/$s/proxy-sustained.json"
    docker rm bench-oha >/dev/null
    echo "$tw" > "$OUT/$s/proxy-sustained-timewait"
    echo "  $s proxy-sustained done (TIME_WAIT at 20/40/60/80 s:$tw)"
  done
fi
echo "done. run: python3 summarize.py"
