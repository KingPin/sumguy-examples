#!/usr/bin/env bash
# Restore drill: boot a throwaway Vaultwarden from a backup archive on another port.
# Never touches the live instance. Usage: ./drill.sh /backups/vaultwarden-....tar.gz [port]
set -euo pipefail

ARCHIVE="${1:?usage: $0 archive.tar.gz [port]}"
PORT="${2:-8099}"
IMAGE="${IMAGE:-vaultwarden/server:1.37.4}"
DRILL="$(mktemp -d)"
NAME="vw-drill-$$"
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; rm -rf "$DRILL"; }
trap cleanup EXIT

tar -xzf "$ARCHIVE" -C "$DRILL"
echo "integrity_check: $(sqlite3 "$DRILL/db.sqlite3" 'PRAGMA integrity_check;')"
echo "users in backup: $(sqlite3 "$DRILL/db.sqlite3" 'SELECT count(*) FROM users;')"

docker run -d --name "$NAME" -p "127.0.0.1:$PORT:80" -v "$DRILL:/data" "$IMAGE" >/dev/null
for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:$PORT/alive" >/dev/null 2>&1; then
    echo "drill instance is alive on http://127.0.0.1:$PORT"
    echo "Log in with a real account to confirm, then press Enter to tear down."
    [ -t 0 ] && read -r _
    exit 0
  fi
  sleep 1
done
echo "drill instance did not come up" >&2
docker logs "$NAME" >&2
exit 1
