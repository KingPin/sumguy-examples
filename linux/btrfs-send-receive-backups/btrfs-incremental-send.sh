#!/usr/bin/env bash
# Incremental btrfs send over SSH. Run as root (or via sudo) on the source host.
# Usage: btrfs-incremental-send.sh SOURCE_SUBVOL SNAP_DIR USER@HOST REMOTE_DIR
# Example: btrfs-incremental-send.sh /mnt/data/files /mnt/data/.snapshots backup@backup-host /mnt/backup/files
# Non-root remote user: set RSUDO=sudo and allow NOPASSWD sudo for btrfs on the target.
# Deletes nothing. Snapshot pruning is up to you (or btrbk).
# If a send dies midway, the target keeps a partial, writable subvolume. It is
# skipped as a parent (only read-only snapshots count), but delete it by hand:
#   btrfs subvolume delete REMOTE_DIR/NAME
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: $0 SOURCE_SUBVOL SNAP_DIR USER@HOST REMOTE_DIR" >&2
  exit 2
fi
src=$1 snapdir=$2 host=$3 rdir=$4
rsudo=${RSUDO:-}
name=$(basename "$src")
new="${name}.$(date +%Y%m%dT%H%M%S)"

mkdir -p "$snapdir"
btrfs subvolume snapshot -r "$src" "$snapdir/$new"

# Read-only snapshot names on the target. A partial receive stays writable,
# so it never gets picked as a parent.
remote_names=$(ssh "$host" "for d in '$rdir'/*; do $rsudo btrfs property get -ts \"\$d\" ro 2>/dev/null | grep -q true && basename \"\$d\"; done; true")

# Newest older local snapshot whose name also exists on the target.
# Name match only: it trusts you never renamed or rebuilt either side.
parent=""
for s in $(ls -1 "$snapdir" | grep "^${name}\." | sort -r); do
  [ "$s" = "$new" ] && continue
  if printf '%s\n' "$remote_names" | grep -qx "$s"; then
    parent=$s
    break
  fi
done

if [ -n "$parent" ]; then
  echo "incremental send, parent: $parent"
  btrfs send -p "$snapdir/$parent" "$snapdir/$new" | ssh "$host" "$rsudo btrfs receive '$rdir'"
else
  echo "no common parent found, sending a full stream"
  btrfs send "$snapdir/$new" | ssh "$host" "$rsudo btrfs receive '$rdir'"
fi
echo "done: $new"
