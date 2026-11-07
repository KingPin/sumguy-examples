#!/usr/bin/env bash
# Runs the Part 5 admin-path probes and writes results-<date>-<mode>/.
# ./run.sh            baseline: the proxies as Part 4 left them (no admin protection at all)
# ./run.sh trap       admin protection the way most guides add it (compose.trap.yml + trap/)
# ./run.sh hardened   the Part 5 fixes (compose.hardened.yml + hardened/)
# Each mode runs probe.sh per proxy, then ../audit.sh against all three.
set -u  # no -e: a failed probe is a result, not a reason to stop
cd "$(dirname "$0")"
mode=${1:-baseline}
case $mode in
  baseline) ;;
  trap|hardened) export COMPOSE_FILE=compose.yml:compose.$mode.yml ;;
  *) echo "usage: $0 [baseline|trap|hardened]"; exit 1 ;;
esac
out=results-$(date +%F)-$mode
mkdir -p "$out"

# 1. Throwaway CA and an RSA 2048 leaf cert for app.example.test and traefik.example.test
if [ ! -f certs/app.crt ]; then
  mkdir -p certs
  openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=Lab Test CA" \
    -keyout certs/ca.key -out certs/ca.crt 2>/dev/null
  openssl req -newkey rsa:2048 -nodes -subj "/CN=app.example.test" \
    -keyout certs/app.key -out certs/app.csr 2>/dev/null
  openssl x509 -req -in certs/app.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial -days 30 \
    -extfile <(printf 'subjectAltName=DNS:app.example.test,DNS:traefik.example.test') -out certs/app.crt 2>/dev/null
  chmod 644 certs/*.key  # containers run as non-root users; throwaway lab keys only
fi

# 2. Fresh containers
docker compose down -v --remove-orphans >/dev/null 2>&1 || true
docker compose build -q
docker compose up -d
sleep 6
docker compose images > "$out/versions.txt"
{ echo "caddy $(docker compose exec -T caddy caddy build-info | head -1)"
  docker compose exec -T caddy caddy build-info | grep ratelimit
  docker compose exec -T traefik traefik version | grep -E 'Version|Go version'
  echo "app: node $(docker compose exec -T backend node --version), express $(docker compose exec -T backend node -p 'require("express/package.json").version')"
  echo "client: $(docker compose exec -T client-out curl --version | head -1 | cut -d' ' -f1-2)"
  echo "host: $(curl --version | head -1 | cut -d' ' -f1-2), $(docker --version)"
} >> "$out/versions.txt"

# 3. Probes
for t in nginx:172.31.50.21 caddy:172.31.50.22 traefik:172.31.50.23; do
  IFS=: read -r svc ip <<< "$t"; echo "== $svc"
  bash probe.sh "$svc" "$ip" > "$out/probe-$svc.txt" 2>&1
done
for p in "nginx 8081 8443" "caddy 8082 9443" "traefik 8083 10443"; do
  set -- $p
  bash ../audit.sh "$2" "$3" > "$out/audit-$1.txt" 2>&1
done

docker compose down -v >/dev/null
echo "done: $out/"
