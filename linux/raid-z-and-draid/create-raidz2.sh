#!/usr/bin/env bash
# create-raidz2.sh — Build a 6-drive RAID-Z2 test pool using loop devices
#
# Uses loop-backed image files only. Will NOT touch any real /dev/sd* devices.
# Requires: ZFS installed (zpool, zfs), sudo
# Tested on: Ubuntu 24.04 with OpenZFS 2.3

set -euo pipefail

POOL_NAME="raidz2-test"
IMG_DIR="/tmp/zfs-test-raidz2"
IMG_SIZE="512M"
NUM_DRIVES=6

# Safety check — refuse to run if ZFS isn't installed
if ! command -v zpool &>/dev/null; then
    echo "ERROR: zpool not found. Install OpenZFS first." >&2
    exit 1
fi

# Safety check — refuse to proceed if the pool already exists
if zpool list "$POOL_NAME" &>/dev/null; then
    echo "ERROR: Pool '$POOL_NAME' already exists. Destroy it first:" >&2
    echo "  sudo zpool destroy $POOL_NAME" >&2
    exit 1
fi

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
echo "==> Creating RAID-Z2 pool: $POOL_NAME"
echo "    Layout: raidz2 across ${NUM_DRIVES} drives"
echo "    Parity: 2 drives (survives any 2 simultaneous failures)"
echo "    Usable: ~${NUM_DRIVES-2}/${NUM_DRIVES} capacity = ~67%"
echo ""

zpool create -f "$POOL_NAME" raidz2 "${LOOP_DEVS[@]}"

echo "==> Pool created. Status:"
echo ""
zpool status "$POOL_NAME"

echo ""
echo "==> Pool list (check usable capacity):"
zpool list "$POOL_NAME"

echo ""
echo "==> Creating a test dataset and writing data"
zfs create "${POOL_NAME}/data"
echo "Hello from RAID-Z2" > "/$(zfs get -H -o value mountpoint ${POOL_NAME}/data)/test.txt"
echo "    Wrote test file to ${POOL_NAME}/data"

echo ""
echo "==> Verifying checksum integrity with a scrub"
zpool scrub "$POOL_NAME"
# Wait for scrub to finish (it's fast on a fresh pool with no real data)
while zpool status "$POOL_NAME" | grep -q "scrub in progress"; do
    sleep 2
done
zpool status "$POOL_NAME" | grep "scan:"

echo ""
echo "==> Test complete. Cleaning up pool and loop devices."
echo "    (Comment out the cleanup lines below if you want to inspect the pool first)"
echo ""

zpool destroy "$POOL_NAME"
for dev in "${LOOP_DEVS[@]}"; do
    losetup -d "$dev"
done
rm -rf "$IMG_DIR"

echo "==> Cleanup done. Loop devices and image files removed."
echo ""
echo "Key takeaways:"
echo "  - RAID-Z2 uses variable-width stripes (no read-modify-write penalty)"
echo "  - Every block has a checksum — run 'zpool scrub' monthly"
echo "  - 6-drive Z2: 4 drives usable data, 2 drives parity (~67% efficiency)"
echo "  - Add more vdevs to the pool for more IOPS, not more drives per vdev"
