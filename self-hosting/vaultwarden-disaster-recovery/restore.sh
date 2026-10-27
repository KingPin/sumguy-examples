#!/usr/bin/env bash
# Restore a backup.sh archive into the live data dir. Current data is moved aside, never deleted.
# Usage: ./restore.sh /backups/vaultwarden-YYYYmmdd-HHMMSS.tar.gz
# Env: DATA_DIR (default /srv/vaultwarden/vw-data), COMPOSE_DIR (default /srv/vaultwarden)
# Encrypted archives (.age): decrypt first with: age -d -i key.txt -o out.tar.gz in.tar.gz.age
set -euo pipefail

ARCHIVE="${1:?usage: $0 archive.tar.gz}"
DATA_DIR="${DATA_DIR:-/srv/vaultwarden/vw-data}"
COMPOSE_DIR="${COMPOSE_DIR:-/srv/vaultwarden}"
ASIDE="$DATA_DIR.old-$(date '+%Y%m%d-%H%M%S')"

( cd "$COMPOSE_DIR" && docker compose stop vaultwarden )

[ -e "$DATA_DIR" ] && mv "$DATA_DIR" "$ASIDE" && echo "old data moved to $ASIDE"
mkdir -p "$DATA_DIR"
tar -xzf "$ARCHIVE" -C "$DATA_DIR"

# The backup came from .backup, so a stale WAL would corrupt it. None is in the archive, but be sure.
rm -f "$DATA_DIR/db.sqlite3-wal" "$DATA_DIR/db.sqlite3-shm"

( cd "$COMPOSE_DIR" && docker compose up -d vaultwarden )

echo "integrity_check: $(sqlite3 "$DATA_DIR/db.sqlite3" 'PRAGMA integrity_check;')"
