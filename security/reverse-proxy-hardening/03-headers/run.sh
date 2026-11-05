#!/usr/bin/env bash
# Runs the Part 3 header audit and writes results-<date>-<mode>/.
# ./run.sh            baseline: the proxies as Part 2 left them (HSTS is the only security header)
# ./run.sh trap       security headers added the way most guides do it (compose.trap.yml + trap/)
# ./run.sh hardened   the Part 3 fixes (compose.hardened.yml + hardened/)
# Each mode runs headers.sh (curl), a raw dump of /app's headers, browser.py (Chromium), and ../audit.sh
# against all three proxies.
# Set CHROMIUM=/path/to/chromium to use a system browser instead of Playwright's.
set -u  # no -e: a failed probe is a result, not a reason to stop
cd "$(dirname "$0")"
mode=${1:-baseline}
case $mode in
  baseline) ;;
  trap)     export COMPOSE_FILE=compose.yml:compose.trap.yml ;;
  hardened) export COMPOSE_FILE=compose.yml:compose.hardened.yml ;;
  *) echo "usage: $0 [baseline|trap|hardened]"; exit 1 ;;
esac
out=results-$(date +%F)-$mode
mkdir -p "$out"

# 1. Throwaway CA and an RSA 2048 leaf cert for app.example.test (same shape as Parts 1 and 2)
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

# 2. Fresh containers
docker compose down -v --remove-orphans >/dev/null 2>&1 || true
docker compose up -d
sleep 5
docker compose images > "$out/versions.txt"
{ echo "caddy $(docker compose exec -T caddy caddy build-info | head -1)"
  docker compose exec -T traefik traefik version | grep -E 'Version|Go version'
  echo "browser: $(python3 -c 'import importlib.metadata as m; print("playwright", m.version("playwright"))') $( ${CHROMIUM:-false} --version 2>/dev/null || echo "(Playwright's bundled Chromium)")"
  echo "host: $(curl --version | head -1 | cut -d' ' -f1-2), $(docker --version)"
} >> "$out/versions.txt"

# 3. Probes
for p in "nginx 8081 8443" "caddy 8082 9443" "traefik 8083 10443"; do
  set -- $p; echo "== $1"
  bash headers.sh "$3" > "$out/headers-$1.txt" 2>&1
  # /app's headers unsorted: when a header appears twice, the browser may care which copy came last
  curl -s -k -m 10 -o /dev/null -D - --resolve "app.example.test:$3:127.0.0.1" "https://app.example.test:$3/app" \
    | tr -d '\r' > "$out/app-raw-$1.txt"
  python3 browser.py "$3" > "$out/browser-$1.txt" 2>&1
  bash ../audit.sh "$2" "$3" > "$out/audit-$1.txt" 2>&1
done

docker compose down -v >/dev/null
echo "done: $out/"
