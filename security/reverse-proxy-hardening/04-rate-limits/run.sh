#!/usr/bin/env bash
# Runs the Part 4 rate-limit probes and writes results-<date>-<mode>/.
# ./run.sh            baseline: the proxies as Part 3 left them (no rate limits)
# ./run.sh trap       limits the way most guides add them (compose.trap.yml + trap/)
# ./run.sh trusting   trap limits plus a real-IP setup that trusts every sender (compose.trusting.yml + trusting/)
# ./run.sh hardened   the Part 4 fixes, plus two one-change-off variants (compose.hardened.yml + hardened/)
# Each mode runs probe.sh per proxy, then ../audit.sh against the three main proxies.
set -u  # no -e: a failed probe is a result, not a reason to stop
cd "$(dirname "$0")"
mode=${1:-baseline}
case $mode in
  baseline) ;;
  trap|trusting|hardened) export COMPOSE_FILE=compose.yml:compose.$mode.yml ;;
  *) echo "usage: $0 [baseline|trap|trusting|hardened]"; exit 1 ;;
esac
out=results-$(date +%F)-$mode
mkdir -p "$out"

# 1. Throwaway CA and an RSA 2048 leaf cert for app.example.test (same shape as Parts 1 to 3)
if [ ! -f certs/app.crt ]; then
  mkdir -p certs
  openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=Lab Test CA" \
    -keyout certs/ca.key -out certs/ca.crt 2>/dev/null
  openssl req -newkey rsa:2048 -nodes -subj "/CN=app.example.test" \
    -keyout certs/app.key -out certs/app.csr 2>/dev/null
  openssl x509 -req -in certs/app.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial -days 30 \
    -extfile <(printf 'subjectAltName=DNS:app.example.test') -out certs/app.crt 2>/dev/null
  chmod 644 certs/*.key  # containers run as non-root users; throwaway lab keys only
fi

# 2. Fresh containers. The rate-limited Caddy is a custom build (Dockerfile.caddy).
docker compose down -v --remove-orphans >/dev/null 2>&1 || true
[ "$mode" != baseline ] && docker compose build -q caddy
docker compose up -d
sleep 5
docker compose images > "$out/versions.txt"
{ echo "caddy $(docker compose exec -T caddy caddy build-info | head -1)"
  docker compose exec -T caddy caddy build-info | grep ratelimit
  docker compose exec -T traefik traefik version | grep -E 'Version|Go version'
  echo "client: $(docker compose exec -T client-a curl --version | head -1 | cut -d' ' -f1-2)"
  echo "host: $(curl --version | head -1 | cut -d' ' -f1-2), $(docker --version)"
} >> "$out/versions.txt"

# 3. Probes
targets="nginx:9001:172.31.40.21 caddy:9002:172.31.40.22 traefik:9003:172.31.40.23"
[ "$mode" = hardened ] && targets="$targets caddy-nostrict:9004:172.31.40.24 traefik-notrust:9005:172.31.40.25"
for t in $targets; do
  IFS=: read -r svc port ip <<< "$t"; echo "== $svc"
  bash probe.sh "$svc" "$port" "$ip" > "$out/probe-$svc.txt" 2>&1
done
for p in "nginx 8081 8443" "caddy 8082 9443" "traefik 8083 10443"; do
  set -- $p
  bash ../audit.sh "$2" "$3" > "$out/audit-$1.txt" 2>&1
done

docker compose down -v >/dev/null
echo "done: $out/"
