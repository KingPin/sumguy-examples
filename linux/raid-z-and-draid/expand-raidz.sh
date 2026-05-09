#!/usr/bin/env bash
# expand-raidz.sh — Demonstrate adding a drive to an existing RAID-Z vdev
#
# RAID-Z expansion was introduced in OpenZFS 2.3 (2024).
# This script creates a 5-drive RAID-Z2 pool and expands it to 6 drives.
#
# Uses loop-backed image files only. Will NOT touch any real /dev/sd* devices.
# Requires: ZFS installed (OpenZFS 2.3+), sudo
# Tested on: Ubuntu 24.04 with OpenZFS 2.3

set -euo pipefail

POOL_NAME="expand-test"
IMG_DIR="/tmp/zfs-test-expand"
IMG_SIZE="512M"

# Safety check — refuse to run if ZFS isn't installed
if ! command -v zpool &>/dev/null; then
    echo "ERROR: zpool not found. Install OpenZFS first." >&2
    exit 1
fi

# Check OpenZFS version — RAID-Z expansion requires 2.3+
ZFS_VER=$(zfs --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+' | head -1 || echo "0.0")
ZFS_MAJOR=$(echo "$ZFS_VER" | cut -d. -f1)
ZFS_MINOR=$(echo "$ZFS_VER" | cut -d. -f2)
if [[ "$ZFS_MAJOR" -lt 2 ]] || [[ "$ZFS_MAJOR" -eq 2 && "$ZFS_MINOR" -lt 3 ]]; then
    echo "ERROR: RAID-Z expansion requires OpenZFS 2.3+. You have: $ZFS_VER" >&2
    echo "       Upgrade to OpenZFS 2.3 or later to use this feature." >&2
    exit 1
fi

# Safety check — refuse to proceed if the pool already exists
if zpool list "$POOL_NAME" &>/dev/null; then
    echo "ERROR: Pool '$POOL_NAME' already exists. Destroy it first:" >&2
    echo "  sudo zpool destroy $POOL_NAME" >&2
    exit 1
fi

echo "==> RAID-Z Expansion Demo (OpenZFS 2.3+)"
echo ""
echo "    Step 1: Create a 5-drive RAID-Z2 pool"
echo "    Step 2: Write some data"
echo "    Step 3: Attach a 6th drive to expand the vdev"
echo "    Step 4: Watch the expansion progress"
echo ""

mkdir -p "$IMG_DIR"

# Create 6 images (5 for initial pool + 1 for expansion)
LOOP_DEVS=()
for i in $(seq 1 6); do
    IMG="${IMG_DIR}/drive${i}.img"
    truncate -s "$IMG_SIZE" "$IMG"
    LOOP=$(losetup --find --show "$IMG")
    LOOP_DEVS+=("$LOOP")
    echo "    drive${i}.img -> $LOOP"
done

echo ""
echo "==> Step 1: Creating 5-drive RAID-Z2 pool: $POOL_NAME"
# Use the first 5 loop devices
INITIAL_DEVS=("${LOOP_DEVS[@]:0:5}")
EXPAND_DEV="${LOOP_DEVS[5]}"

zpool create -f "$POOL_NAME" raidz2 "${INITIAL_DEVS[@]}"

echo ""
echo "==> Pool status BEFORE expansion (5 drives):"
zpool status "$POOL_NAME"
echo ""
zpool list "$POOL_NAME"

echo ""
echo "==> Step 2: Writing test data to pool"
zfs create "${POOL_NAME}/data"
MOUNT=$(zfs get -H -o value mountpoint "${POOL_NAME}/data")
# Write ~50MB of test data so there's something to reflow
dd if=/dev/urandom of="${MOUNT}/testdata.bin" bs=1M count=50 status=none
echo "    Wrote 50MB of test data to ${POOL_NAME}/data"

echo ""
echo "==> Step 3: Attaching 6th drive to expand the RAID-Z2 vdev"
echo "    Command: zpool attach $POOL_NAME raidz2-0 $EXPAND_DEV"
echo ""

# Get the vdev name from pool status
VDEV_NAME=$(zpool status "$POOL_NAME" | grep -oP 'raidz2-\d+' | head -1)
if [[ -z "$VDEV_NAME" ]]; then
    VDEV_NAME="raidz2-0"
fi

zpool attach "$POOL_NAME" "$VDEV_NAME" "$EXPAND_DEV"

echo "==> Drive attached. Pool is now expanding."
echo ""
echo "==> Pool status AFTER attaching 6th drive:"
zpool status "$POOL_NAME"
echo ""

echo "==> Step 4: Waiting for expansion to progress..."
echo "    (In production this takes hours for large pools)"
echo "    Watching for up to 60 seconds on this test pool..."
echo ""

WAITED=0
while zpool status "$POOL_NAME" | grep -qE "resilver|expanding|reflow"; do
    if [[ $WAITED -ge 60 ]]; then
        echo "    (Still in progress — moving on for demo purposes)"
        break
    fi
    STATUS=$(zpool status "$POOL_NAME" | grep -E "scan:|expanding" | head -1 | xargs)
    echo "    [${WAITED}s] $STATUS"
    sleep 5
    WAITED=$((WAITED + 5))
done

echo ""
echo "==> Final pool status after expansion:"
zpool status "$POOL_NAME"
echo ""
zpool list "$POOL_NAME"

echo ""
echo "==> Important caveat about RAID-Z expansion:"
echo "    - Existing blocks written under the 5-drive geometry remain as-is"
echo "    - New writes use the 6-drive geometry immediately"
echo "    - Usable capacity increases incrementally as old blocks are rewritten"
echo "    - Run 'zpool status' to check reflow progress on real pools"
echo ""
echo "==> Cleaning up pool and loop devices."

zpool destroy "$POOL_NAME"
for dev in "${LOOP_DEVS[@]}"; do
    losetup -d "$dev"
done
rm -rf "$IMG_DIR"

echo "==> Cleanup done."
echo ""
echo "Key takeaways:"
echo "  - RAID-Z expansion adds ONE drive at a time to an existing vdev"
echo "  - Requires OpenZFS 2.3+ — check your version with 'zfs --version'"
echo "  - Existing data keeps old parity ratio until rewritten (expected behavior)"
echo "  - Capacity is not fully available immediately — reflow happens over time"
echo "  - This is NOT the same as adding a new vdev — it grows the existing vdev geometry"
