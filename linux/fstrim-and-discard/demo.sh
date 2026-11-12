#!/bin/sh
# TRIM vs a sparse disk image: the same mechanism a thin-provisioned VM disk uses.
# Run inside a privileged container (needs loop devices). Cleans up after itself.
set -eu
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null && apt-get install -y -qq e2fsprogs util-linux >/dev/null 2>&1
IMG=/work/disk.img
MNT=/mnt/t
ondisk() { du -h "$IMG" | cut -f1; }
fill() { dd if=/dev/urandom of=$MNT/big bs=1M count=1024 status=none; sync; }

rm -f "$IMG"; truncate -s 2G "$IMG"
LOOP=$(losetup --find --show "$IMG")
trap "umount $MNT 2>/dev/null || true; losetup -d $LOOP; rm -f $IMG" EXIT
uname -r
lsblk --discard "$LOOP"
mkfs.ext4 -q -E nodiscard "$LOOP"
mkdir -p $MNT

echo "--- Part 1: periodic TRIM (mount without discard, run fstrim) ---"
mount -o nodiscard "$LOOP" $MNT
echo "after mkfs:      $(ondisk) on disk"
fill;              echo "after 1 GiB:     $(ondisk) on disk"
rm $MNT/big; sync; echo "after rm:        $(ondisk) on disk"
fstrim -v $MNT;    echo "after fstrim:    $(ondisk) on disk"
fstrim -v $MNT
umount $MNT; mount -o nodiscard "$LOOP" $MNT
echo "after remount:"; fstrim -v $MNT
umount $MNT

echo "--- Part 2: continuous discard (mount -o discard) ---"
mount -o discard "$LOOP" $MNT
fill;              echo "after 1 GiB:     $(ondisk) on disk"
rm $MNT/big; sync; sleep 2; echo "after rm:        $(ondisk) on disk"
umount $MNT
