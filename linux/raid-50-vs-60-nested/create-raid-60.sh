#!/usr/bin/env bash
# create-raid-60.sh — Build a RAID 60 array using loop devices (safe for testing)
#
# Architecture: two 4-drive RAID 6 sub-arrays (md2, md3) striped together as RAID 0 (md20)
# No real disks are used. All storage comes from sparse files via losetup.
#
# RAID 60 requires minimum 8 drives (two 4-drive RAID 6 sub-arrays).
# Each sub-array tolerates 2 simultaneous drive failures independently.
#
# Tested on: Ubuntu 24.04, Debian 12

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
SPARSE_DIR="/tmp"
SPARSE_SIZE="1G"          # each "drive" size
NUM_DRIVES=8              # 4 per sub-array × 2 sub-arrays
IMG_PREFIX="raid60-test"

MD_SUB_A="/dev/md2"
MD_SUB_B="/dev/md3"
MD_TOP="/dev/md20"

# ── Safety check: refuse if any argument looks like a real disk ───────────────
for arg in "$@"; do
  if [[ "$arg" =~ ^/dev/sd || "$arg" =~ ^/dev/nvme || "$arg" =~ ^/dev/hd ]]; then
    echo "ERROR: This script only operates on loop devices." >&2
    echo "Do not pass real disk paths. Aborting." >&2
    exit 1
  fi
done

# ── Require root ─────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root (sudo)." >&2
  exit 1
fi

echo "==> Creating ${NUM_DRIVES} sparse image files (${SPARSE_SIZE} each) in ${SPARSE_DIR}/"
echo "    RAID 60 = two 4-drive RAID 6 sub-arrays striped with RAID 0"
echo "    Each sub-array tolerates 2 simultaneous drive failures"

LOOP_DEVS=()
IMG_FILES=()

for i in $(seq 0 $((NUM_DRIVES - 1))); do
  IMG="${SPARSE_DIR}/${IMG_PREFIX}-${i}.img"
  IMG_FILES+=("$IMG")
  truncate -s "${SPARSE_SIZE}" "${IMG}"
  LOOP=$(losetup --find --show "${IMG}")
  LOOP_DEVS+=("$LOOP")
  echo "    drive ${i}: ${IMG} → ${LOOP}"
done

echo ""
echo "==> Loop devices:"
printf '    %s\n' "${LOOP_DEVS[@]}"

# Split into two groups of 4
GROUP_A=("${LOOP_DEVS[0]}" "${LOOP_DEVS[1]}" "${LOOP_DEVS[2]}" "${LOOP_DEVS[3]}")
GROUP_B=("${LOOP_DEVS[4]}" "${LOOP_DEVS[5]}" "${LOOP_DEVS[6]}" "${LOOP_DEVS[7]}")

echo ""
echo "==> Step 1: Creating RAID 6 sub-array A (${MD_SUB_A}) across drives 0-3"
echo "    Drives: ${GROUP_A[*]}"
echo "    Can survive 2 simultaneous drive failures in this group"
mdadm --create "${MD_SUB_A}" \
  --level=6 \
  --raid-devices=4 \
  --metadata=1.2 \
  --force \
  "${GROUP_A[@]}"

echo ""
echo "==> Step 2: Creating RAID 6 sub-array B (${MD_SUB_B}) across drives 4-7"
echo "    Drives: ${GROUP_B[*]}"
echo "    Can survive 2 simultaneous drive failures in this group"
mdadm --create "${MD_SUB_B}" \
  --level=6 \
  --raid-devices=4 \
  --metadata=1.2 \
  --force \
  "${GROUP_B[@]}"

echo ""
echo "==> Waiting for sub-arrays to be ready..."
while grep -E 'resync|recovery' /proc/mdstat >/dev/null 2>&1; do
  echo -n "."
  sleep 2
done
echo " done."

echo ""
echo "==> Step 3: Creating top-level RAID 0 stripe (${MD_TOP}) across sub-arrays"
echo "    This stripe has no additional redundancy — sub-arrays provide the protection"
mdadm --create "${MD_TOP}" \
  --level=0 \
  --raid-devices=2 \
  --chunk=512 \
  --force \
  "${MD_SUB_A}" "${MD_SUB_B}"

echo ""
echo "==> RAID 60 built. Current /proc/mdstat:"
echo "────────────────────────────────────────"
cat /proc/mdstat
echo "────────────────────────────────────────"

echo ""
echo "==> Detail on each component:"
echo ""
echo "--- Sub-array A (${MD_SUB_A}) ---"
mdadm --detail "${MD_SUB_A}" | grep -E 'Level|State|Devices|Active|Size|UUID'

echo ""
echo "--- Sub-array B (${MD_SUB_B}) ---"
mdadm --detail "${MD_SUB_B}" | grep -E 'Level|State|Devices|Active|Size|UUID'

echo ""
echo "--- Top-level stripe (${MD_TOP}) ---"
mdadm --detail "${MD_TOP}" | grep -E 'Level|State|Devices|Active|Size|UUID'

echo ""
echo "==> Capacity breakdown for this 8 × 1GB RAID 60:"
echo "    Usable = (drives_per_group - 2) × num_groups × drive_size"
echo "    Usable = (4 - 2) × 2 × 1 GB = 4 GB"
echo "    Overhead = 4 drives worth of parity (50% — expected for RAID 60 at min size)"
echo ""
echo "==> Success! You now have a RAID 60 array at ${MD_TOP}"
echo "    You could: mkfs.ext4 ${MD_TOP} && mount ${MD_TOP} /mnt/test"
echo "    To persist: mdadm --detail --scan >> /etc/mdadm/mdadm.conf"
echo ""

# ── Cleanup ───────────────────────────────────────────────────────────────────
read -r -p "Clean up (stop arrays, detach loop devices, remove images)? [y/N] " CONFIRM
if [[ "${CONFIRM,,}" == "y" ]]; then
  echo "==> Tearing down..."
  mdadm --stop "${MD_TOP}" 2>/dev/null || true
  mdadm --stop "${MD_SUB_B}" 2>/dev/null || true
  mdadm --stop "${MD_SUB_A}" 2>/dev/null || true

  for dev in "${LOOP_DEVS[@]}"; do
    losetup -d "${dev}" 2>/dev/null || true
  done

  for img in "${IMG_FILES[@]}"; do
    rm -f "${img}"
  done

  echo "==> Cleanup complete."
else
  echo "==> Left in place. To clean up manually:"
  echo "    sudo mdadm --stop ${MD_TOP} ${MD_SUB_B} ${MD_SUB_A}"
  echo "    sudo losetup -D"
  echo "    rm -f ${SPARSE_DIR}/${IMG_PREFIX}-*.img"
fi
