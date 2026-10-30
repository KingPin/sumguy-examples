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

# ---------------------------------------------------------------- run mode
PHASE=${PHASE:-matrix}
STEP_S=${STEP_S:-$(( DUR < 20 ? DUR : 20 ))}  # mix-ramp step length; the smoke form shortens it
case $PHASE in
  matrix)
    PHASE_DIR=matrix
    CONFIGS=${CONFIGS:-${DESIGNS:-monolith micro}}
    SCENARIOS=${SCENARIOS:-browse-max cart-max checkout-max mix-max mix-fixed mix-ramp} ;;
  sweep)
    PHASE_DIR=sweep; RUNS=1
    CONFIGS=${CONFIGS:-${DESIGNS:-monolith micro}}
    SCENARIOS=${SCENARIOS:-$(for v in ${SWEEP_VUS:-16 32 64 128 256}; do printf 'mix-max-v%s ' "$v"; done)} ;;
  scaling)
    [[ ${B:-} == 2 || ${B:-} == 4 ]] || { echo "scaling needs B=2 or B=4"; exit 1; }
    PHASE_DIR=scaling-B$B
    CONFIGS=${CONFIGS:-mono micro-even micro-tuned}
    if [ "$B" = 4 ]; then SCENARIOS=${SCENARIOS:-mix-max mix-ramp}; else SCENARIOS=${SCENARIOS:-mix-max}; fi
    if [[ $CONFIGS == *micro-tuned* ]]; then
      [ -f "tuned-B$B.env" ] || { echo "tuned-B$B.env missing: run tune_split.py first"; exit 1; }
      source "tuned-B$B.env"
    fi ;;
  *) echo "unknown PHASE $PHASE"; exit 1 ;;
esac
if [ -e "$OUT/$PHASE_DIR" ]; then echo "$OUT/$PHASE_DIR exists; set OUT to a new directory"; exit 1; fi

design_of() { case $1 in monolith|mono) echo monolith ;; *) echo micro ;; esac; }
calibrated() {  # $1 scenario label
  case $1 in
    mix-fixed) [ "${FIXED_RATE:-0}" -gt 0 ] ;;
    mix-ramp)  [ "${RAMP_HI:-0}" -gt 0 ] ;;
    *) true ;;
  esac
}

noise_snap() {  # "name usage_usec" for user.slice and every system.slice child except this invocation's containers
  local mine dir u
  mine=$(docker ps -q --no-trunc --filter "name=^${P}" | sed 's/^/docker-/; s/$/.scope/')
  echo "user.slice $(awk '/^usage_usec/{print $2}' /sys/fs/cgroup/user.slice/cpu.stat)"
  for dir in /sys/fs/cgroup/system.slice/*/; do
    dir=${dir%/}
    if grep -qxF "${dir##*/}" <<<"$mine"; then continue; fi
    # A child that exits between the glob and the read is left out, so noise_delta counts it as gone.
    u=$(awk '/^usage_usec/{print $2}' "$dir/cpu.stat" 2>/dev/null) || continue
    if [ -n "$u" ]; then echo "${dir##*/} $u"; fi
  done
}

# k6 is never in either snapshot (it starts after the first and is gone before the second), so
# child counters are used instead of the system.slice parent. A child that exited in between
# would drop its CPU from the sum and hide noise, so it is reported and the test counts as noisy.
# A child whose counter went down was restarted under the same name: its CPU is unknown, so it is gone too.
noise_delta() {  # $1 before, $2 after -> "usec_used gone_children"
  awk 'NR == FNR {a[$1] = $2; next} {v = $2 - a[$1]; if (v < 0) n++; else d += v; delete a[$1]}
       END {for (k in a) n++; print d + 0, n + 0}' "$1" "$2"
}

snap() {  # one line per container: name usage_usec nr_throttled throttled_usec. Fails if a container's cgroup is gone.
  local s c
  for s in "$@"; do
    c=$(cg "$P$s") && [ -f "$c/cpu.stat" ] || return 1
    awk -v n="$s" '/^usage_usec/{u=$2} /^nr_throttled/{t=$2} /^throttled_usec/{tu=$2} END{print n, u, t + 0, tu + 0}' \
      "$c/cpu.stat" || return 1
  done
}

sampler() {  # $1 output file, $2 k6 cgroup, rest = app cgroups. Rewrites "peak_summed_memory k6_usec" every second.
  local out=$1 k6cg=$2 peak=0 k6u=0 m d u; shift 2
  while :; do
    m=0; for d in "$@"; do m=$(( m + $(cat "$d/memory.current") )); done
    if (( m > peak )); then peak=$m; fi
    if u=$(awk '/^usage_usec/{print $2}' "$k6cg/cpu.stat" 2>/dev/null) && [ -n "$u" ]; then k6u=$u; fi
    echo "$peak $k6u" > "$out.tmp" && mv "$out.tmp" "$out"   # a kill mid-write never leaves $out empty
    sleep 1
  done
}

run_k6() {  # $1 k6 scenario, $2 seconds, $3 PHASE (0 warm-up, 1 measured), $4 summary path or empty. Detached.
  local mnt=() sum=/tmp/warmup.json
  if [ -n "$4" ]; then mnt=(-v "$(cd "$(dirname "$4")" && pwd):/out"); sum="/out/$(basename "$4")"; fi
  docker run -d --name "${P}k6" --network "$NET" --cpuset-cpus "$K6_CPUS" --user "$(id -u):$(id -g)" \
    -v "$PWD/k6:/scripts:ro" "${mnt[@]}" \
    -e SCENARIO="$1" -e DUR="$2" -e PHASE="$3" -e VUS="$VUS" -e RATE="$FIXED_RATE" \
    -e RAMP_LO="$RAMP_LO" -e RAMP_HI="$RAMP_HI" -e STEP_S="$STEP_S" -e SUMMARY="$sum" \
    "$K6_IMAGE" run --quiet /scripts/shop.js >/dev/null
}

finish_k6() {  # wait for k6; exit 99 means a threshold crossed, which only an empty no-op trend can cause
  local rc
  rc=$(docker wait "${P}k6")
  docker logs "${P}k6" >> "$LOGS/k6.log" 2>&1 || true
  docker rm "${P}k6" >/dev/null
  [ "$rc" = 0 ] || [ "$rc" = 99 ]
}

RETRY=()
measure() {  # $1 config, $2 label, $3 k6 scenario, $4 run, $5 seconds, $6 VUs
  local c=$1 label=$2 sc=$3 r=$4 dur=$5 d; d=$(design_of "$c")
  local VUS=$6  # dynamic scope: run_k6 reads it
  local f="$OUT/$PHASE_DIR/$c/$label-r$r.json" status=ok idle=0 nd="0 0" t0=0 t1=0 spid x svcs cgs=()
  LOGS="$OUT/logs/$PHASE_DIR/$c/$label-r$r"
  mkdir -p "$(dirname "$f")" "$LOGS"
  svcs=$(services "$d")
  if { start_pg "$d" && start_app "$d" "$c"; }; then
    for x in $svcs; do cgs+=("$(cg "$P$x")"); done
    for x in "${cgs[@]}"; do idle=$(( idle + $(cat "$x/memory.current") )); done
    { run_k6 warmup 10 0 "" && finish_k6; } || status=failed
  else
    status=failed
  fi
  # A container that crashed mid-test fails its snap: the test is failed and retried, the invocation goes on.
  if [ $status = ok ] && ! snap $svcs pg > "$f.before"; then status=failed; fi
  if [ $status = ok ]; then
    noise_snap > "$f.noise0"; t0=$(date +%s%N)
    run_k6 "$sc" "$dur" 1 "$f.k6.json"
    sampler "$f.sampler" "$(cg "${P}k6")" "${cgs[@]}" & spid=$!
    finish_k6 || status=failed
    snap $svcs pg > "$f.after" || status=failed
    noise_snap > "$f.noise1"; t1=$(date +%s%N)
    nd=$(noise_delta "$f.noise0" "$f.noise1")
    kill $spid 2>/dev/null || true; wait $spid 2>/dev/null || true  # the sampler exits by itself if an app cgroup vanished
    for x in $svcs; do docker stop -t 10 "$P$x" >/dev/null; done  # pool stats print on SIGTERM
  fi
  cleanup
  status=$(F=$f STATUS=$status PHASE_DIR=$PHASE_DIR D=$d C=$c SC=$label R=$r DUR=$dur VUS=$VUS B=${B:-} \
    NOISE=$nd T0=$t0 T1=$t1 IDLE=$idle STEP_S=$STEP_S FIXED_RATE=$FIXED_RATE RAMP_LO=$RAMP_LO \
    RAMP_HI=$RAMP_HI NOISE_LIMIT=$NOISE_LIMIT python3 - <<'PY'
import json, os
e = os.environ
f = e["F"]
out = {"phase": e["PHASE_DIR"], "design": e["D"], "config": e["C"], "budget": int(e["B"]) if e["B"] else None,
       "scenario": e["SC"], "run": int(e["R"]), "dur_s": int(e["DUR"]), "step_s": int(e["STEP_S"]),
       "vus": int(e["VUS"]), "rate_iters": float(e["FIXED_RATE"]),
       "ramp_iters": [float(e["RAMP_LO"]), float(e["RAMP_HI"])], "status": e["STATUS"]}
if out["status"] == "ok" and not os.path.exists(f + ".k6.json"):
    out["status"] = "failed"
if out["status"] == "ok":
    try:
        rows = lambda p: {l.split()[0]: [int(x) for x in l.split()[1:]] for l in open(p)}
        b, a = rows(f + ".before"), rows(f + ".after")
        wall = (int(e["T1"]) - int(e["T0"])) / 1e9
        peak, k6u = (int(x) for x in open(f + ".sampler").read().split())
        used, gone = (int(x) for x in e["NOISE"].split())
        out.update(
            wall_s=wall,
            cpu_s={k: (a[k][0] - b[k][0]) / 1e6 for k in a},
            nr_throttled={k: a[k][1] - b[k][1] for k in a},
            throttled_s={k: (a[k][2] - b[k][2]) / 1e6 for k in a},
            k6_cores=k6u / 1e6 / wall,
            noise_cores=used / 1e6 / wall, noise_gone=gone,
            mem_idle_bytes=int(e["IDLE"]), mem_peak_bytes=peak,
            k6=json.load(open(f + ".k6.json"))["metrics"],
        )
        # A vanished child or a negative sum means the noise number is not trustworthy.
        if out["noise_cores"] > float(e["NOISE_LIMIT"]) or gone or used < 0:
            out["status"] = "noisy"
    except (OSError, ValueError, KeyError) as ex:  # missing or malformed measurement file; update() never ran
        out.update(status="failed", error=repr(ex))
for ext in (".before", ".after", ".sampler", ".sampler.tmp", ".noise0", ".noise1", ".k6.json"):
    if os.path.exists(f + ext):
        os.remove(f + ext)
json.dump(out, open(f, "w"))
print(out["status"])
PY
)
  echo "  $c $label run $r: $status"
  if [ "$status" != ok ]; then RETRY+=("$c $label $sc $r $dur $VUS"); fi
}

write_env() {  # provenance for this phase
  local s i
  {
    echo "date: $(date -u +%FT%TZ)"
    # The box gets the kit by rsync without .git, so the sync step writes KIT_REV first.
    if [ -f KIT_REV ]; then echo "kit: $(cat KIT_REV)"
    else echo "kit: $(git rev-parse --short HEAD 2>/dev/null || echo unknown)$(git diff --quiet HEAD -- . 2>/dev/null || echo ' (dirty)')"; fi
    echo "kernel: $(uname -r)"; lscpu | grep 'Model name'
    echo "os: $(. /etc/os-release && echo "$PRETTY_NAME")"
    echo "docker: $(docker version -f '{{.Server.Version}}')"
    echo "phase: $PHASE_DIR duration: ${DUR}s runs: $RUNS step: ${STEP_S}s budget: ${B:-none}"
    echo "cpus: k6=$K6_CPUS pg=$PG_CPUS app=$APP_CPUS"
    echo "resolved: VUS=$VUS FIXED_RATE=$FIXED_RATE RAMP_LO=$RAMP_LO RAMP_HI=$RAMP_HI NOISE_LIMIT=$NOISE_LIMIT"
    echo "--- sibling map (lscpu -e=CPU,CORE)"; lscpu -e=CPU,CORE
    echo "--- bench.env"; cat bench.env
    if [ "$PHASE" = scaling ] && [ -f "tuned-B$B.env" ]; then echo "--- tuned-B$B.env"; cat "tuned-B$B.env"; fi
    echo "--- images"
    for s in monolith gateway catalog cart orders; do
      echo "image mvm-$s:bench $(docker image inspect -f '{{.Size}} {{.Id}}' "mvm-$s:bench")"
    done
    for i in "$PG_IMAGE" "$K6_IMAGE" "$GO_IMAGE" "$DISTROLESS_IMAGE"; do echo "image $i $(docker image inspect -f '{{.Size}} {{index .RepoDigests 0}}' "$i")"; done
    echo "--- docker stats before the run"; docker stats --no-stream --format '{{.Name}} {{.CPUPerc}} {{.MemUsage}}'
  } > "$OUT/$PHASE_DIR/env.txt"
}

build
mkdir -p "$OUT/$PHASE_DIR"
write_env
noise_snap > "$OUT/.noise0"; sleep 10; noise_snap > "$OUT/.noise1"
read -r nd gone < <(noise_delta "$OUT/.noise0" "$OUT/.noise1"); rm -f "$OUT"/.noise[01]
if [ "$gone" != 0 ] || awk -v d="$nd" -v lim="$NOISE_LIMIT" 'BEGIN{exit !(d < 0 || d / 10e6 > lim)}'; then
  echo "background CPU is $(awk -v d="$nd" 'BEGIN{printf "%.2f", d / 10e6}') cores, $gone service(s) exited meanwhile (limit $NOISE_LIMIT). Pause something, then retry."
  docker stats --no-stream
  rm -rf "${OUT:?}/$PHASE_DIR"
  exit 1
fi

for c in $CONFIGS; do
  LOGS="$OUT/logs/$PHASE_DIR/$c/contract"; contract_check "$(design_of "$c")"
  for r in $(seq 1 "$RUNS"); do
    for label in $SCENARIOS; do
      if ! calibrated "$label"; then echo "  skip $label: not calibrated in bench.env"; continue; fi
      sc=$label; vus=$VUS; dur=$DUR
      if [[ $label == mix-max-v* ]]; then sc=mix-max; vus=${label#mix-max-v}; fi
      if [ "$label" = mix-ramp ]; then dur=$(( 10 * STEP_S )); fi
      measure "$c" "$label" "$sc" "$r" "$dur" "$vus"
    done
  done
  if [ "$PHASE" = matrix ] && [ "${SUSTAINED:-1}" = 1 ]; then measure "$c" mix-sustained mix-sustained 1 90 "$VUS"; fi
done

if [ ${#RETRY[@]} -gt 0 ]; then
  todo=("${RETRY[@]}"); RETRY=()
  echo "re-running ${#todo[@]} failed or noisy test(s) once"
  for t in "${todo[@]}"; do
    read -r c label sc r dur vus <<<"$t"
    f="$OUT/$PHASE_DIR/$c/$label-r$r.json" l="$OUT/logs/$PHASE_DIR/$c/$label-r$r"
    st=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["status"])' "$f")
    mv "$f" "${f%.json}.$st.json"
    if [ -d "$l" ]; then mv "$l" "$l.$st"; fi  # keep the first attempt's logs
    measure "$c" "$label" "$sc" "$r" "$dur" "$vus"
  done
fi
# Contract checks run without a quota, so their GOMAXPROCS lines would not describe the measured runs.
grep -rh --exclude-dir=contract GOMAXPROCS "$OUT/logs/$PHASE_DIR" 2>/dev/null | sed 's/^[0-9/: ]*//' | sort -u | sed 's/^/gomaxprocs: /' >> "$OUT/$PHASE_DIR/env.txt" || true
echo "done. ${#RETRY[@]} test(s) still not ok. Run: python3 summarize.py $OUT"
