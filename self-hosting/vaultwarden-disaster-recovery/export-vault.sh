#!/usr/bin/env bash
# Password-protected encrypted_json export of your personal vault with the Bitwarden CLI.
# Cron-friendly. Needs: bw, and these env vars:
#   BW_CLIENTID, BW_CLIENTSECRET  personal API key (Account settings > Security > Keys)
#   BW_PASSWORD                   master password (or set PASSFILE to a 0600 file, first line = password)
#   EXPORT_PASSWORD               password that protects the export file
# Optional: BW_SERVER (default https://vault.example.com), OUT_DIR (default /backups/exports)
set -euo pipefail

BW_SERVER="${BW_SERVER:-https://vault.example.com}"
OUT_DIR="${OUT_DIR:-/backups/exports}"
OUT="$OUT_DIR/vault-$(date '+%Y%m%d').json"
: "${EXPORT_PASSWORD:?set EXPORT_PASSWORD}"

mkdir -p "$OUT_DIR"
umask 077

bw logout >/dev/null 2>&1 || true
bw config server "$BW_SERVER" >/dev/null
bw login --apikey >/dev/null

if [ -n "${PASSFILE:-}" ]; then
  BW_SESSION="$(bw unlock --passwordfile "$PASSFILE" --raw)"
else
  : "${BW_PASSWORD:?set BW_PASSWORD or PASSFILE}"
  BW_SESSION="$(bw unlock --passwordenv BW_PASSWORD --raw)"
fi
export BW_SESSION

bw sync >/dev/null
bw export --format encrypted_json --password "$EXPORT_PASSWORD" --output "$OUT" >/dev/null
bw lock >/dev/null
bw logout >/dev/null
echo "wrote $OUT"
