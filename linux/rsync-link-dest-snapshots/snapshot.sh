#!/usr/bin/env bash
# Hard-link snapshot backup with rsync --link-dest.
# Usage: snapshot.sh SRC DEST [KEEP]
#   SRC   directory to back up (local, or user@host:/path for a pull over SSH)
#   DEST  snapshot root; holds 2026-11-09_030000/ style dirs plus a "latest" symlink
#   KEEP  how many snapshots to keep (default 14)
set -euo pipefail

SRC=${1:?usage: snapshot.sh SRC DEST [KEEP]}
DEST=${2:?usage: snapshot.sh SRC DEST [KEEP]}
KEEP=${3:-14}
[ "$KEEP" -ge 1 ] || { echo "KEEP must be at least 1" >&2; exit 1; }
RSYNC_OPTS=${RSYNC_OPTS:--aH --numeric-ids --delete}

mkdir -p "$DEST"
exec 9>"$DEST/.lock"
flock -n 9 || { echo "another snapshot is running" >&2; exit 1; }

name=$(date +%Y-%m-%d_%H%M%S)
[ -e "$DEST/$name" ] && { echo "snapshot $name already exists" >&2; exit 1; }

# A leftover .partial from a failed run is reused: rsync resumes into it.
partial="$DEST/.partial"
mkdir -p "$partial"

args=()
# Relative --link-dest paths resolve against the destination dir ($partial),
# so ../latest means $DEST/latest.
[ -L "$DEST/latest" ] && args+=(--link-dest=../latest)

rc=0
# shellcheck disable=SC2086  # RSYNC_OPTS is meant to word-split
rsync $RSYNC_OPTS "${args[@]}" "${SRC%/}/" "$partial/" || rc=$?

# 24 = source files vanished mid-run, normal on a live system.
if [ "$rc" -ne 0 ] && [ "$rc" -ne 24 ]; then
    echo "rsync failed with exit $rc; latest left untouched" >&2
    exit "$rc"
fi

mv "$partial" "$DEST/$name"
ln -s "$name" "$DEST/latest.tmp"
mv -T "$DEST/latest.tmp" "$DEST/latest"

# Prune: names sort chronologically, so drop everything but the newest KEEP.
mapfile -t old < <(find "$DEST" -mindepth 1 -maxdepth 1 -type d \
    -name '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9]' \
    -printf '%f\n' | sort | head -n "-$KEEP")
for d in "${old[@]}"; do
    rm -rf -- "${DEST:?}/$d"
done
echo "snapshot $name done, kept $(find "$DEST" -mindepth 1 -maxdepth 1 -type d -name '[0-9]*' | wc -l)"
