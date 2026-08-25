#!/usr/bin/env bash
# Generates the Authelia secret files referenced by compose.yaml.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)/authelia/secrets"
mkdir -p "$DIR"

# tr -d '\n' matters: Authelia reads these files verbatim, and a trailing
# newline inside a Postgres password fails as an opaque connection error.
openssl rand -base64 64 | tr -d '\n' > "$DIR/jwt_secret"
openssl rand -base64 64 | tr -d '\n' > "$DIR/session_secret"
openssl rand -base64 64 | tr -d '\n' > "$DIR/storage_encryption_key"
openssl rand -base64 32 | tr -d '\n' > "$DIR/postgres_password"

if [ ! -f "$DIR/smtp_password" ]; then
  printf '%s' 'replace_with_your_smtp_password' > "$DIR/smtp_password"
fi

chmod 600 "$DIR"/*
echo "Secrets written to $DIR"
