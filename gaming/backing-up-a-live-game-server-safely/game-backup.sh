#!/usr/bin/env bash
set -euo pipefail

CONTAINER=mc
DATASET=tank/games/minecraft
MOUNT=/srv/minecraft
SNAP=restic-tmp

export RESTIC_REPOSITORY=/mnt/backup/mc-restic
export RESTIC_PASSWORD_FILE=/etc/restic/password

rcon() { docker exec "$CONTAINER" rcon-cli "$@"; }

saves_off=0
cleanup() {
  # Always turn saving back on, even if the snapshot failed.
  if [ "$saves_off" -eq 1 ]; then
    rcon save-on || echo "WARNING: save-on failed, fix this now" >&2
  fi
  zfs destroy "$DATASET@$SNAP" 2>/dev/null || true
}
trap cleanup EXIT

# Leftover snapshot from a crashed run would make zfs snapshot fail.
zfs destroy "$DATASET@$SNAP" 2>/dev/null || true

# Quiet window starts here.
saves_off=1
rcon save-off
rcon save-all flush
zfs snapshot "$DATASET@$SNAP"
rcon save-on
saves_off=0
# Quiet window ends here. The server is writing again.

restic backup "$MOUNT/.zfs/snapshot/$SNAP" \
  --tag minecraft --host mc-server

restic forget --tag minecraft --host mc-server \
  --keep-hourly 24 --keep-daily 7 --keep-weekly 4
