#!/usr/bin/env bash
# replace-drive.sh
# Demonstrates mdadm --fail / --remove / --add flow using loop devices.
# Builds a 4-drive RAID 5, simulates one drive failure, replaces it, and
# watches the rebuild to completion.
#
# SAFE: refuses to operate on real block devices (/dev/sd*, /dev/nvme*, etc.)
# Run as root.
#
# Companion to: https://sumguy.com/posts/mdadm-day-2-operations/

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
WORKDIR="/tmp/mdadm-replace-demo"
ARRAY="/dev/md9"        # Use md9 to avoid colliding with real arrays
DRIVE_SIZE_MB=128       # Each fake drive in megabytes
NUM_DRIVES=4
CHUNK=512               # Chunk size in KiB

# ── Safety check ─────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run as root." >&2
  exit 1
fi

# Refuse to run if any of the loop devices we'd use are backed by real disks
# (paranoia: this script should only ever touch loop devices)
for dev in /dev/sda /dev/sdb /dev/sdc /dev/nvme0n1; do
  if [[ -b "$dev" ]]; then
    echo "WARNING: Real disk $dev detected on this system."
    echo "This script uses loop devices only. Verify no real md arrays share $ARRAY."
  fi
done

if [[ -b "$ARRAY" ]]; then
  echo "ERROR: $ARRAY already exists. Stop it first or choose a different md device." >&2
  exit 1
fi

# ── Cleanup trap ─────────────────────────────────────────────────────────────
cleanup() {
  echo ""
  echo "==> Cleaning up..."
  mdadm --stop "$ARRAY" 2>/dev/null || true
  for img in "$WORKDIR"/drive{0..4}.img; do
    loop=$(losetup -j "$img" 2>/dev/null | cut -d: -f1 || true)
    [[ -n "$loop" ]] && losetup -d "$loop" 2>/dev/null || true
  done
  rm -rf "$WORKDIR"
  echo "==> Done."
}
trap cleanup EXIT

# ── Setup ────────────────────────────────────────────────────────────────────
echo "==> Creating work directory: $WORKDIR"
mkdir -p "$WORKDIR"

echo "==> Creating $NUM_DRIVES drive images (${DRIVE_SIZE_MB}MB each)..."
for i in $(seq 0 $((NUM_DRIVES - 1))); do
  dd if=/dev/zero of="$WORKDIR/drive${i}.img" bs=1M count="$DRIVE_SIZE_MB" status=none
done
# One extra drive for the replacement
dd if=/dev/zero of="$WORKDIR/drive4.img" bs=1M count="$DRIVE_SIZE_MB" status=none

echo "==> Attaching loop devices..."
declare -a LOOPS=()
for i in $(seq 0 4); do
  loop=$(losetup --find --show "$WORKDIR/drive${i}.img")
  LOOPS+=("$loop")
  echo "    drive${i}.img -> $loop"
done

ACTIVE_LOOPS=("${LOOPS[@]:0:$NUM_DRIVES}")
SPARE_LOOP="${LOOPS[4]}"

# ── Create RAID 5 ─────────────────────────────────────────────────────────────
echo ""
echo "==> Creating RAID 5 on ${ACTIVE_LOOPS[*]}..."
mdadm --create "$ARRAY" \
  --level=5 \
  --raid-devices="$NUM_DRIVES" \
  --chunk="$CHUNK" \
  --metadata=1.2 \
  --assume-clean \
  "${ACTIVE_LOOPS[@]}"

echo ""
echo "==> Initial array state:"
mdadm --detail "$ARRAY"

echo ""
echo "==> /proc/mdstat:"
cat /proc/mdstat

# ── Simulate drive failure ────────────────────────────────────────────────────
FAILING_DRIVE="${ACTIVE_LOOPS[1]}"
echo ""
echo "==> Simulating failure of drive: $FAILING_DRIVE"
mdadm "$ARRAY" --fail "$FAILING_DRIVE"
echo "    Marked failed."

sleep 1
mdadm "$ARRAY" --remove "$FAILING_DRIVE"
echo "    Removed from array."

echo ""
echo "==> Degraded array state:"
cat /proc/mdstat

# ── Replace with new drive ────────────────────────────────────────────────────
echo ""
echo "==> Adding replacement drive: $SPARE_LOOP"
mdadm "$ARRAY" --add "$SPARE_LOOP"

echo ""
echo "==> Watching rebuild (Ctrl+C to abort watch — cleanup will still run)..."
echo ""

# Poll until rebuild done
while grep -q "recovery\|reshape" /proc/mdstat 2>/dev/null; do
  clear
  echo "--- $(date) ---"
  cat /proc/mdstat
  sleep 3
done

echo ""
echo "==> Rebuild complete."
echo ""
echo "==> Final array state:"
mdadm --detail "$ARRAY"

echo ""
echo "==> Mismatch count: $(cat /sys/block/md9/md/mismatch_cnt 2>/dev/null || echo 'N/A')"
echo ""
echo "SUCCESS: Drive replacement demonstrated on loop devices."
