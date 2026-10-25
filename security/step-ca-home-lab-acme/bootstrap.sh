#!/usr/bin/env bash
# Starts step-ca, exports its root certificate, then starts Caddy.
set -euo pipefail
cd "$(dirname "$0")"

[ -f ca_password.txt ] || { head -c 32 /dev/urandom | base64 > ca_password.txt; chmod 600 ca_password.txt; }

docker compose up -d --wait ca
docker compose cp ca:/home/step/certs/root_ca.crt ./root_ca.crt
docker compose up -d caddy
echo "Root certificate: $PWD/root_ca.crt"
