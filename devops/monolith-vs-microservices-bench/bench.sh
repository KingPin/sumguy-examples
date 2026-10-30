#!/usr/bin/env bash
# Monolith vs microservices on one box, with CPU pinning.
# Usage: ./bench.sh [duration_seconds] [runs]   run PHASE (default matrix; 30 s per test, 3 runs)
#        ./bench.sh contract [record]            contract check on both designs (record: monolith only, rewrites expected/)
# Env: PHASE=matrix|sweep|scaling, B=2|4 (scaling), DESIGNS, SCENARIOS, CONFIGS, SWEEP_VUS, SUSTAINED=0|1,
#      OUT, APP_PORT, K6_CPUS, PG_CPUS, APP_CPUS, plus the image and calibration values in bench.env
set -euo pipefail
cd "$(dirname "$0")"
source ./bench.env

MODE=run
if [ "${1:-}" = contract ]; then MODE=contract; shift; fi
DUR=${1:-30}
RUNS=${2:-3}
P=mvm-$$-                         # prefix for every Docker object this invocation creates
NET=${P}net
APP_PORT=${APP_PORT:-18080}
OUT=${OUT:-results-$(date +%F)}
LOGS=${TMPDIR:-/tmp}/mvm-$$-logs  # where cleanup saves container logs; measure() points it per test

cg() { echo "/sys/fs/cgroup/system.slice/docker-$(docker inspect -f '{{.Id}}' "$1").scope"; }
services() { if [ "$1" = monolith ]; then echo monolith; else echo gateway catalog cart orders; fi; }

cleanup() {  # save logs, then remove only this invocation's containers and network
  local ids id n
  ids=$(docker ps -aq --filter "name=^${P}")
  if [ -n "$ids" ]; then
    mkdir -p "$LOGS"
    for id in $ids; do
      n=$(docker inspect -f '{{.Name}}' "$id"); n=${n#/}
      docker logs "$id" > "$LOGS/${n#"$P"}.log" 2>&1 || true
    done
    docker rm -f $ids >/dev/null
  fi
  docker network rm "$NET" >/dev/null 2>&1 || true
}
trap 'kill $(jobs -p) 2>/dev/null || true; cleanup' EXIT   # jobs: the run-mode memory sampler
trap 'exit 130' INT TERM

wait_for() {  # $1 = seconds of wall clock, rest = command; polls every 0.5 s
  local end=$((SECONDS + $1)); shift
  until "$@" >/dev/null 2>&1; do
    ((SECONDS < end)) || return 1
    sleep 0.5
  done
}
# -m 2: a port that accepts but never answers cannot stall wait_for past its deadline.
code() { curl -s -m 2 -o /dev/null -w '%{http_code}' -X "$1" "http://127.0.0.1:$APP_PORT$2"; }
# The three probes reach every service: catalog, cart, and orders (empty cart -> 409).
app_ready() { [ "$(code GET /products/1)" = 200 ] && [ "$(code GET /cart/1)" = 200 ] && [ "$(code POST /checkout/1)" = 409 ]; }
psql_pg() { docker exec -e PGPASSWORD=bench "${P}pg" psql -X -q -h 127.0.0.1 -U postgres "$@"; }

build() {
  local s
  for s in monolith gateway catalog cart orders; do
    docker build -q --build-arg CMD=$s --build-arg GO_IMAGE="$GO_IMAGE" \
      --build-arg DISTROLESS_IMAGE="$DISTROLESS_IMAGE" -t "mvm-$s:bench" app/ >/dev/null
  done
  for s in "$PG_IMAGE" "$K6_IMAGE" "$GO_IMAGE" "$DISTROLESS_IMAGE"; do docker pull -q "$s" >/dev/null; done
}

start_pg() {  # $1 = monolith | micro. Fresh data directory on tmpfs every time.
  docker network create "$NET" >/dev/null
  docker run -d --name "${P}pg" --network "$NET" --network-alias pg --cpuset-cpus "$PG_CPUS" \
    --tmpfs /var/lib/postgresql -e POSTGRES_PASSWORD=bench -v "$PWD:/kit:ro" "$PG_IMAGE" >/dev/null
  # TCP comes up only after the image's init step, so this cannot pass early.
  wait_for 30 docker exec "${P}pg" pg_isready -q -h 127.0.0.1 -U postgres || { echo "postgres not ready"; return 1; }
  local micro=0 db=shop n
  if [ "$1" = micro ]; then micro=1; db=catalog; fi
  psql_pg -v micro=$micro -f /kit/seed.sql >/dev/null || return 1
  n=$(psql_pg -tA -d $db -c 'SELECT count(*) FROM products')
  [ "$n" = 10000 ] || { echo "seed check failed: $n products"; return 1; }
}

quota() {  # $1 config, $2 service -> value for --cpus, empty for no quota
  case $1 in
    mono) echo "$B" ;;
    micro-even) awk -v b="$B" 'BEGIN{print b / 4}' ;;
    micro-tuned) local v=Q_${2^^}; echo "${!v}" ;;
  esac
}

run_app() {  # $1 service, $2 config, rest = NAME=value env pairs
  local s=$1 c=$2 q e want; shift 2
  local args=(-d --name "$P$s" --network "$NET" --network-alias "$s" --cpuset-cpus "$APP_CPUS")
  if [[ $s == monolith || $s == gateway ]]; then args+=(--network-alias app -p "127.0.0.1:$APP_PORT:8080"); fi
  q=$(quota "$c" "$s")
  if [ -n "$q" ]; then args+=(--cpus "$q"); fi
  for e in "$@"; do args+=(-e "$e"); done
  docker run "${args[@]}" "mvm-$s:bench" >/dev/null
  if [ -n "$q" ]; then  # Docker reads --cpus 0 as "no limit": check the kernel got what we asked for
    want=$(awk -v q="$q" 'BEGIN{printf "%d 100000", q * 100000 + 0.5}')
    [ "$(cat "$(cg "$P$s")/cpu.max")" = "$want" ] || { echo "cpu.max on $s is not '$want'"; exit 1; }
  fi
}

start_app() {  # $1 design, $2 config
  local u="postgres://%s:bench@pg:5432/%s?sslmode=disable"
  if [ "$1" = monolith ]; then
    run_app monolith "$2" "PG_URL=$(printf "$u" shop shop)" POOL_MAX=30
  else
    run_app catalog "$2" "PG_URL=$(printf "$u" catalog catalog)" POOL_MAX=10
    run_app cart    "$2" "PG_URL=$(printf "$u" cart cart)" POOL_MAX=10 CATALOG_ADDR=catalog:9090
    run_app orders  "$2" "PG_URL=$(printf "$u" orders orders)" POOL_MAX=10 CATALOG_ADDR=catalog:9090 CART_ADDR=cart:9090
    run_app gateway "$2" CATALOG_ADDR=catalog:9090 CART_ADDR=cart:9090 ORDERS_ADDR=orders:9090
  fi
  wait_for 30 app_ready || { echo "$1 not ready"; return 1; }
}

contract_check() {  # $1 design, $2 = --record or empty. Exits the script on any mismatch.
  { start_pg "$1" && start_app "$1" "$1"; } || exit 1
  python3 contract.py "http://127.0.0.1:$APP_PORT" expected/contract.json ${2:-} || exit 1
  cleanup
}

if [ "$MODE" = contract ]; then
  build
  if [ "${1:-}" = record ]; then contract_check monolith --record; else contract_check monolith; contract_check micro; fi
  exit 0
fi

echo "run mode arrives in Task 11"
exit 1
