#!/usr/bin/env bash
# grow-raid5-to-raid6.sh
# Converts a 4-drive RAID 5 (loop devices) to a 5-drive RAID 6 using
# mdadm --grow --level=6 and a --backup-file on a separate filesystem.
#
# SAFE: operates on loop devices only. Refuses if passed real block devices.
# Run as root.
#
# Companion to: https://sumguy.com/posts/mdadm-day-2-operations/

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
WORKDIR="/tmp/mdadm-grow-demo"
ARRAY="/dev/md8"        # Use md8 to avoid colliding with real arrays
DRIVE_SIZE_MB=200
CHUNK=512
BACKUP_FILE="/tmp/mdadm-level-backup.bin"

# ── Safety ────────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run as root." >&2
  exit 1
fi

if [[ -b "$ARRAY" ]]; then
  echo "ERROR: $ARRAY already exists. Stop it or choose a different md device." >&2
  exit 1
fi

if [[ -f "$BACKUP_FILE" ]]; then
  echo "ERROR: Backup file $BACKUP_FILE already exists. Remove it first." >&2
  exit 1
fi

# ── Cleanup trap ─────────────────────────────────────────────────────────────
cleanup() {
  echo ""
  echo "==> Cleaning up..."
  mdadm --stop "$ARRAY" 2>/dev/null || true
  for img in "$WORKDIR"/drive{0..4}.img; do
    [[ -f "$img" ]] || continue
    loop=$(losetup -j "$img" 2>/dev/null | cut -d: -f1 || true)
    [[ -n "$loop" ]] && losetup -d "$loop" 2>/dev/null || true
  done
  rm -rf "$WORKDIR"
  rm -f "$BACKUP_FILE"
  echo "==> Done."
}
trap cleanup EXIT

# ── Setup ────────────────────────────────────────────────────────────────────
echo "==> Creating work directory: $WORKDIR"
mkdir -p "$WORKDIR"

echo "==> Creating 5 drive images (${DRIVE_SIZE_MB}MB each)..."
for i in $(seq 0 4); do
  dd if=/dev/zero of="$WORKDIR/drive${i}.img" bs=1M count="$DRIVE_SIZE_MB" status=none
done

echo "==> Attaching loop devices..."
declare -a LOOPS=()
for i in $(seq 0 4); do
  loop=$(losetup --find --show "$WORKDIR/drive${i}.img")
  LOOPS+=("$loop")
  echo "    drive${i}.img -> $loop"
done

RAID5_LOOPS=("${LOOPS[@]:0:4}")
EXTRA_LOOP="${LOOPS[4]}"

# ── Create RAID 5 ─────────────────────────────────────────────────────────────
echo ""
echo "==> Creating RAID 5 on ${RAID5_LOOPS[*]}..."
mdadm --create "$ARRAY" \
  --level=5 \
  --raid-devices=4 \
  --chunk="$CHUNK" \
  --metadata=1.2 \
  --assume-clean \
  "${RAID5_LOOPS[@]}"

echo ""
echo "==> Initial RAID 5 state:"
mdadm --detail "$ARRAY" | grep -E "RAID Level|State|Active Devices|Array Size"

# ── Wait for any initial sync to settle ───────────────────────────────────────
echo ""
echo "==> Waiting for array to settle..."
while grep -q "resync\|recovery" /proc/mdstat 2>/dev/null; do
  sleep 2
done
echo "    Settled."

# ── Add the 5th drive ─────────────────────────────────────────────────────────
echo ""
echo "==> Adding 5th drive (future RAID 6 member): $EXTRA_LOOP"
mdadm "$ARRAY" --add "$EXTRA_LOOP"

# Let mdadm register it as spare
sleep 2

echo ""
echo "==> Array with spare:"
mdadm --detail "$ARRAY" | grep -E "RAID Level|State|Active Devices|Spare Devices"

# ── Convert RAID 5 → RAID 6 ───────────────────────────────────────────────────
echo ""
echo "==> Converting RAID 5 (4 drives) → RAID 6 (5 drives)..."
echo "    Using backup file: $BACKUP_FILE"
echo "    (In production: store backup file on a SEPARATE filesystem, not on the array)"
echo ""

mdadm "$ARRAY" --grow \
  --level=6 \
  --raid-devices=5 \
  --backup-file="$BACKUP_FILE"

echo ""
echo "==> Reshape started. Watching progress..."
echo ""

# Poll until reshape complete
while grep -q "reshape\|recovery\|resync" /proc/mdstat 2>/dev/null; do
  clear
  echo "--- $(date) ---"
  cat /proc/mdstat
  echo ""
  echo "Backup file size: $(du -sh "$BACKUP_FILE" 2>/dev/null | cut -f1 || echo 'N/A')"
  sleep 5
done

echo ""
echo "==> Reshape complete. Backup file can be removed."
rm -f "$BACKUP_FILE"

# ── Verify ────────────────────────────────────────────────────────────────────
echo ""
echo "==> Final array state:"
mdadm --detail "$ARRAY"

LEVEL=$(mdadm --detail "$ARRAY" | grep "RAID Level" | awk '{print $NF}')
ACTIVE=$(mdadm --detail "$ARRAY" | grep "Active Devices" | awk '{print $NF}')

echo ""
if [[ "$LEVEL" == "raid6" && "$ACTIVE" == "5" ]]; then
  echo "SUCCESS: Array is now RAID 6 with 5 active devices."
else
  echo "WARNING: Unexpected state — Level=$LEVEL Active=$ACTIVE"
  echo "Check mdadm --detail $ARRAY manually."
fi
