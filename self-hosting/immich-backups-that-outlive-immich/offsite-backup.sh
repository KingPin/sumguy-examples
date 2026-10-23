#!/usr/bin/env bash
# Offsite backup of an Immich install with restic.
# Run daily from cron or a systemd timer, after Immich's own 02:00 database dump.
set -euo pipefail

UPLOAD_LOCATION="${UPLOAD_LOCATION:-/srv/immich}"
: "${RESTIC_REPOSITORY:?set RESTIC_REPOSITORY, e.g. s3:s3.example.com/family-photos}"
: "${RESTIC_PASSWORD_FILE:?set RESTIC_PASSWORD_FILE}"
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE

# 1. Export album and person membership as plain symlink folders.
python3 "$(dirname "$0")/export_metadata.py" --out "$UPLOAD_LOCATION/export" --prefix-to "$UPLOAD_LOCATION"

# 2. Originals, the database dumps, and the export. Skip thumbs and encoded-video
#    (Immich regenerates both).
cd "$UPLOAD_LOCATION"
restic backup --tag immich library upload profile backups export

# 3. Keep 7 daily, 8 weekly, 12 monthly, 5 yearly snapshots, then verify.
restic forget --tag immich --keep-daily 7 --keep-weekly 8 --keep-monthly 12 --keep-yearly 5 --prune
restic check --read-data-subset=5%
