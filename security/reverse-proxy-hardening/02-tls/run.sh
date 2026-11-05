#!/usr/bin/env bash
# Runs the Part 2 TLS audit and writes results-<date>-<mode>/.
# ./run.sh            baseline: the proxies as Part 1 left them, TLS untouched. tls.sh, audit.sh, testssl.sh
# ./run.sh hardened   the Part 2 fixes (compose.hardened.yml + hardened/). Same probes
# ./run.sh trap       hardened, but with a curve list from an older guide. tls.sh and testssl.sh
set -u  # no -e: a failed probe is a result, not a reason to stop
cd "$(dirname "$0")"
mode=${1:-baseline}
case $mode in
  baseline) ;;
  hardened) export COMPOSE_FILE=compose.yml:compose.hardened.yml ;;
  trap)     export COMPOSE_FILE=compose.yml:compose.trap.yml ;;
  *) echo "usage: $0 [baseline|hardened|trap]"; exit 1 ;;
esac
out=results-$(date +%F)-$mode
mkdir -p "$out"

# 1. Throwaway CA and an RSA 2048 leaf cert for app.example.test (same shape as Part 1)
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
{ docker compose exec -T nginx sh -c 'nginx -V 2>&1 | grep OpenSSL'
  echo "caddy $(docker compose exec -T caddy caddy build-info | head -1)"
  docker compose exec -T traefik traefik version | grep -E 'Version|Go version'
  docker run --rm drwetter/testssl.sh:3.2 --version 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -m1 -oE 'testssl.sh version [0-9.]+'
  echo "host: $(openssl version | cut -d' ' -f1-2), $(curl --version | head -1 | cut -d' ' -f1-2), $(docker --version)"
} >> "$out/versions.txt"

# 3. TLS settings from the outside
for p in "nginx 8081 8443" "caddy 8082 9443" "traefik 8083 10443"; do
  set -- $p; echo "== $1"
  bash tls.sh "$3" > "$out/tls-$1.txt" 2>&1
  [ "$mode" = trap ] || bash ../audit.sh "$2" "$3" > "$out/audit-$1.txt" 2>&1
done

# 4. testssl.sh: rating, client simulation, its own view of resumption. Trusts our throwaway CA.
for p in "nginx 8443" "caddy 9443" "traefik 10443"; do
  set -- $p; echo "== testssl $1"
  docker run --rm --network host -v "$PWD/certs:/certs:ro" drwetter/testssl.sh:3.2 \
    --quiet --color 0 --warnings off --add-ca /certs/ca.crt --ip 127.0.0.1 \
    "https://app.example.test:$2" > "$out/testssl-$1.txt" 2>&1 || true
done

# 5. Two config checks with nginx -t (hardened run only)
if [ "$mode" = hardened ]; then
  t=$(mktemp -d)
  printf 'server { listen 443 ssl; ssl_certificate /certs/app.crt; ssl_certificate_key /certs/app.key;\n  ssl_ecdh_curve X25519MLKEM768:X25519:prime256v1:secp384r1; }\n' > "$t/pq.conf"
  printf 'server { listen 443 ssl; ssl_certificate /t/fullchain.crt; ssl_certificate_key /certs/app.key;\n  ssl_stapling on; ssl_stapling_verify on; }\n' > "$t/staple.conf"
  cat certs/app.crt certs/ca.crt > "$t/fullchain.crt"  # nginx needs the issuer to staple at all
  chmod 644 "$t"/*
  {
    echo "### The Part 2 curve list on an older nginx image (OpenSSL 3.0)"
    docker run --rm -v "$t/pq.conf:/etc/nginx/conf.d/pq.conf:ro" -v "$PWD/certs:/certs:ro" nginx:1.26-bookworm \
      sh -c 'openssl version; nginx -t' 2>&1
    echo
    echo "### ssl_stapling on with a certificate that has no OCSP URL (as Let's Encrypt certs have had since 2025)"
    docker run --rm -v "$t/staple.conf:/etc/nginx/conf.d/staple.conf:ro" -v "$t:/t:ro" -v "$PWD/certs:/certs:ro" \
      --entrypoint nginx nginx:1.31.8 -t 2>&1
  } > "$out/nginx-config-checks.txt"
  rm -rf "$t"
fi

docker compose down -v >/dev/null
echo "done: $out/"
