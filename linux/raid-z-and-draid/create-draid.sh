#!/usr/bin/env bash
# create-draid.sh — Build an 11-drive dRAID2:8d:1s pool using loop devices
#
# dRAID2:8d:1s = 2 parity drives, 8 data drives per stripe, 1 distributed spare
# Minimum drives for this layout: 8 data + 2 parity + 1 spare = 11
#
# Uses loop-backed image files only. Will NOT touch any real /dev/sd* devices.
# Requires: ZFS installed (OpenZFS 2.1+), sudo
# Tested on: Ubuntu 24.04 with OpenZFS 2.3

set -euo pipefail

POOL_NAME="draid-test"
IMG_DIR="/tmp/zfs-test-draid"
IMG_SIZE="512M"
NUM_DRIVES=11

# Safety check — refuse to run if ZFS isn't installed
if ! command -v zpool &>/dev/null; then
    echo "ERROR: zpool not found. Install OpenZFS first." >&2
    exit 1
fi

# Check OpenZFS version — dRAID requires 2.1+
ZFS_VER=$(zfs --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+' | head -1 || echo "0.0")
ZFS_MAJOR=$(echo "$ZFS_VER" | cut -d. -f1)
ZFS_MINOR=$(echo "$ZFS_VER" | cut -d. -f2)
if [[ "$ZFS_MAJOR" -lt 2 ]] || [[ "$ZFS_MAJOR" -eq 2 && "$ZFS_MINOR" -lt 1 ]]; then
    echo "ERROR: dRAID requires OpenZFS 2.1+. You have: $ZFS_VER" >&2
    exit 1
fi

# Safety check — refuse to proceed if the pool already exists
if zpool list "$POOL_NAME" &>/dev/null; then
    echo "ERROR: Pool '$POOL_NAME' already exists. Destroy it first:" >&2
    echo "  sudo zpool destroy $POOL_NAME" >&2
    exit 1
fi

echo "==> dRAID Layout: draid2:8d:1s"
echo "    2 parity drives (survives any 2 simultaneous failures)"
echo "    8 data drives per stripe"
echo "    1 distributed spare (capacity spread across all drives)"
echo "    Total drives needed: 11"
echo ""
echo "==> Creating ${NUM_DRIVES} x ${IMG_SIZE} loop device images in ${IMG_DIR}"
mkdir -p "$IMG_DIR"

LOOP_DEVS=()
for i in $(seq 1 $NUM_DRIVES); do
    IMG="${IMG_DIR}/drive${i}.img"
    truncate -s "$IMG_SIZE" "$IMG"
    LOOP=$(losetup --find --show "$IMG")
    LOOP_DEVS+=("$LOOP")
    echo "    drive${i}.img -> $LOOP"
done

echo ""
echo "==> Creating dRAID pool: $POOL_NAME"
zpool create -f "$POOL_NAME" draid2:8d:1s "${LOOP_DEVS[@]}"

echo ""
echo "==> Pool created. Status:"
echo ""
zpool status "$POOL_NAME"

echo ""
echo "==> Pool capacity (note: distributed spare shows as reserved):"
zpool list "$POOL_NAME"

echo ""
echo "==> Virtual spare device listing:"
# dRAID shows virtual spares in zpool status — extract and display
zpool status "$POOL_NAME" | grep -A5 "spares" || echo "    (check 'zpool status $POOL_NAME' for spare details)"

echo ""
echo "==> Creating datasets and writing test data"
zfs create "${POOL_NAME}/data"
zfs create "${POOL_NAME}/data/media"
zfs create "${POOL_NAME}/data/backups"

MOUNT=$(zfs get -H -o value mountpoint "${POOL_NAME}/data")
echo "dRAID2 test data" > "${MOUNT}/test.txt"
echo "    Datasets created under ${POOL_NAME}/data"

echo ""
echo "==> Scrub to verify checksums:"
zpool scrub "$POOL_NAME"
while zpool status "$POOL_NAME" | grep -q "scrub in progress"; do
    sleep 2
done
zpool status "$POOL_NAME" | grep "scan:"

echo ""
echo "==> Test complete. Cleaning up pool and loop devices."

zpool destroy "$POOL_NAME"
for dev in "${LOOP_DEVS[@]}"; do
    losetup -d "$dev"
done
rm -rf "$IMG_DIR"

echo "==> Cleanup done."
echo ""
echo "Key takeaways:"
echo "  - dRAID distributes spare capacity across ALL drives (no dedicated spare sitting idle)"
echo "  - On drive failure: ALL drives participate in rebuild — not just N-1 drives writing to 1 spare"
echo "  - Resilver times drop dramatically vs RAID-Z on large arrays (16+ drives)"
echo "  - dRAID shines at 16+ drives; for <12 drives, RAID-Z2 is simpler and just as good"
echo "  - Syntax: draid<parity>:<data>d:<spares>s — this example is draid2:8d:1s"
