#!/usr/bin/env bash
# Consistent Vaultwarden backup. Runs on the Docker host and needs sqlite3 installed.
# Usage: DATA_DIR=/srv/vaultwarden/vw-data BACKUP_DIR=/backups ./backup.sh
# Optional: AGE_RECIPIENT=age1... encrypts the archive with age. KEEP=14 sets retention.
set -euo pipefail

DATA_DIR="${DATA_DIR:-/srv/vaultwarden/vw-data}"
BACKUP_DIR="${BACKUP_DIR:-/backups}"
KEEP="${KEEP:-14}"
STAMP="$(date '+%Y%m%d-%H%M%S')"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$BACKUP_DIR"
umask 077

# 1. Online-safe copy of the database. Safe while Vaultwarden is running.
sqlite3 "$DATA_DIR/db.sqlite3" ".backup '$WORK/db.sqlite3'"
[ "$(sqlite3 "$WORK/db.sqlite3" 'PRAGMA integrity_check;')" = "ok" ] \
  || { echo "integrity_check failed on fresh backup" >&2; exit 1; }

# 2. The files people forget. Missing ones are skipped (attachments/ and sends/ may not exist).
extras=()
for f in rsa_key.pem rsa_key.pub.pem attachments sends config.json; do
  [ -e "$DATA_DIR/$f" ] && extras+=("$f")
done

ARCHIVE="$BACKUP_DIR/vaultwarden-$STAMP.tar.gz"
tar -czf "$ARCHIVE" -C "$WORK" db.sqlite3 -C "$DATA_DIR" "${extras[@]}"

# 3. Optional encryption. The archive holds rsa_key.pem and plaintext config.json.
if [ -n "${AGE_RECIPIENT:-}" ]; then
  age -r "$AGE_RECIPIENT" -o "$ARCHIVE.age" "$ARCHIVE"
  rm -f "$ARCHIVE"
  ARCHIVE="$ARCHIVE.age"
fi

# 4. Retention: keep the newest $KEEP archives.
# shellcheck disable=SC2012
ls -1t "$BACKUP_DIR"/vaultwarden-*.tar.gz* 2>/dev/null | tail -n +"$((KEEP + 1))" | xargs -r rm -f --

echo "wrote $ARCHIVE"
