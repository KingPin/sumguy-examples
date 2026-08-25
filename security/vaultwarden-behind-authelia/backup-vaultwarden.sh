#!/usr/bin/env bash
# Nightly Vaultwarden + Authelia backup.
# Never `cp` a live SQLite file; use the backup API for a consistent snapshot.
set -euo pipefail

BACKUP_DIR="/mnt/offsite/vaultwarden-backups"
DATE=$(date +%Y%m%d-%H%M%S)
DATA_DIR="/path/to/vaultwarden_data"
DEST="$BACKUP_DIR/$DATE"

mkdir -p "$DEST"

sqlite3 "$DATA_DIR/db.sqlite3" ".backup '$DEST/db.sqlite3'"

# rsa_key signs every session token. Lose it and everyone is logged out.
cp "$DATA_DIR/rsa_key.pem" "$DEST/" 2>/dev/null || true
cp "$DATA_DIR/config.json" "$DEST/" 2>/dev/null || true

rsync -a "$DATA_DIR/attachments/" "$DEST/attachments/"
rsync -a "$DATA_DIR/sends/" "$DEST/sends/"

# Authelia's Postgres holds the TOTP secrets for every enrolled user.
docker exec authelia_postgres pg_dump -U authelia authelia \
  | gzip > "$DEST/authelia.sql.gz"

find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} +

echo "Backup complete: $DATE"
