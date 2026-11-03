#!/usr/bin/env bash
# Runs the full Part 1 audit and writes results-<date>/.
# ./run.sh            stock configs, every probe, testssl.sh scans
# ./run.sh hardened   same probes against compose.hardened.yml (the Part 1 fixes), no scans
set -u  # no -e: a failed probe is a result, not a reason to stop
cd "$(dirname "$0")"
mode=${1:-stock}
out=results-$(date +%F)
if [ "$mode" = hardened ]; then
  export COMPOSE_FILE=compose.yml:compose.hardened.yml
  out=$out-hardened
fi
mkdir -p "$out"
audit=../audit.sh

# 1. Throwaway CA and a leaf cert for app.example.test
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
for i in $(seq 60); do curl -sf -o /dev/null http://127.0.0.1:8181/api/ && break; sleep 2; done  # NPM migrates on first start
docker compose images > "$out/versions.txt"

# 3. Outside-in probes, backend up
for p in "nginx 8081 8443" "caddy 8082 9443" "traefik 8083 10443" "npm 8084 11443"; do
  set -- $p; echo "== $1"; bash "$audit" "$2" "$3" > "$out/$1.txt" 2>&1
done

# 4. Proxy error page when the app is down (container up, port closed)
docker compose exec -T backend touch /tmp/down; sleep 1
for p in "nginx 8443" "caddy 9443" "traefik 10443"; do
  set -- $p
  { echo "### App down: the proxy's own error page"
    curl -sk -m 10 -D - --resolve "app.example.test:$2:127.0.0.1" "https://app.example.test:$2/" | tr -d '\r' | head -c 600; echo
  } > "$out/$1-502.txt"
done
docker compose exec -T backend rm /tmp/down

if [ "$mode" = hardened ]; then
  docker compose down -v >/dev/null
  echo "done: $out/"; exit 0
fi

# 5. Admin surfaces
{
  echo "### Traefik dashboard API on host :8090 -> container :8080 (--api.insecure=true)"
  curl -s http://127.0.0.1:8090/api/version; echo
  # The docker provider sees every container on the host. Only this stack's names are printed;
  # anything else on the test machine is reduced to a count and its backend port.
  curl -s http://127.0.0.1:8090/api/http/services | python3 -c '
import sys, json
mine, other = [], []
for s in json.load(sys.stdin):
    urls = [x["url"] for x in s.get("loadBalancer", {}).get("servers", [])]
    (mine if s["name"].endswith(("-rp-leaks@docker", "@internal")) or s["name"] == "app@docker" else other).append((s["name"], urls))
print("services from this stack:"); [print(" ", n, u) for n, u in mine]
print("services built for OTHER containers on the host:", len(other))
print("  their backend ports:", sorted(u[0].rsplit(":", 1)[1] for n, u in other if u))'
  echo "auto-router reachable by Host header? (Host: nginx-rp-leaks, with the HTTPS redirect on)"
  for port in 8083 10443 8090; do
    scheme=http; [ "$port" = 10443 ] && scheme=https
    echo "  :$port -> $(curl -sk -o /dev/null -w '%{http_code} server=%header{server} location=%{redirect_url}' -H 'Host: nginx-rp-leaks' "$scheme://127.0.0.1:$port/")"
  done
  echo
  echo "### Caddy admin API (default localhost:2019)"
  echo "from inside the caddy container:"; docker compose exec -T caddy wget -qO- http://127.0.0.1:2019/config/ | head -c 900; echo
  echo "from the backend container on the same network:"
  docker compose exec -T backend python -c 'import urllib.request as u; print(u.urlopen("http://caddy:2019/config/",timeout=3).read()[:200])' 2>&1 | tail -1
  echo
  echo "### NPM admin on :81"
  curl -s http://127.0.0.1:8181/api/; echo
  echo "login with the old documented default (admin@example.com / changeme):"
  curl -s -H 'Content-Type: application/json' -d '{"identity":"admin@example.com","secret":"changeme"}' http://127.0.0.1:8181/api/tokens | head -c 300; echo
} > "$out/admin.txt" 2>&1

# 6. TLS scan (protocols, ciphers, rating). Trusts our throwaway CA.
for p in "nginx 8443" "caddy 9443" "traefik 10443"; do
  set -- $p; echo "== testssl $1"
  docker run --rm --network host -v "$PWD/certs:/certs:ro" drwetter/testssl.sh:3.2 \
    --quiet --color 0 --warnings off --add-ca /certs/ca.crt --ip 127.0.0.1 \
    "https://app.example.test:$2" > "$out/testssl-$1.txt" 2>&1 || true
done

# 7. Two first-run traps
{
  echo "### Traefik quick-start flags only (--api.insecure=true --providers.docker, no redirect)"
  docker run -d --rm --name rp-leaks-quickstart --network rp-leaks_default -p 127.0.0.1:8085:80 \
    -v /var/run/docker.sock:/var/run/docker.sock:ro traefik:v3.7.17 --api.insecure=true --providers.docker >/dev/null
  sleep 5
  for h in npm-rp-leaks nginx-rp-leaks caddy-rp-leaks; do
    echo "  Host: $h -> $(curl -s -o /dev/null -w '%{http_code} server=%header{server}' -H "Host: $h" http://127.0.0.1:8085/)"
  done
  docker stop rp-leaks-quickstart >/dev/null
  echo
  echo "### NPM fresh install: can a stranger claim the admin account on :81?"
  curl -s http://127.0.0.1:8181/api/; echo
  curl -s -o /dev/null -w 'POST /api/users (no auth) -> %{http_code}\n' -H 'Content-Type: application/json' \
    -d '{"name":"Mallory","nickname":"m","email":"mallory@example.test","roles":["admin"],"is_disabled":false,"auth":{"type":"password","secret":"stranger-danger-123"}}' \
    http://127.0.0.1:8181/api/users
  curl -s -o /dev/null -w 'login as the new admin -> %{http_code}\n' -H 'Content-Type: application/json' \
    -d '{"identity":"mallory@example.test","secret":"stranger-danger-123"}' http://127.0.0.1:8181/api/tokens
  curl -s http://127.0.0.1:8181/api/; echo
} > "$out/first-run.txt" 2>&1

docker compose down -v >/dev/null
echo "done: $out/"
