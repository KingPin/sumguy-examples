#!/usr/bin/env bash
# monitor.sh — Check health of a nested RAID 50 or RAID 60 array
#
# Prints /proc/mdstat, runs mdadm --detail on each sub-array and the top-level
# stripe, and warns loudly if any array is not in a clean state.
#
# Usage:
#   sudo bash monitor.sh                        # auto-detect all active arrays
#   sudo bash monitor.sh /dev/md0 /dev/md1 /dev/md10   # specify arrays manually
#
# Tested on: Ubuntu 24.04, Debian 12

set -euo pipefail

# ── Color output ─────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # no color

# ── Require root ─────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root (sudo)." >&2
  exit 1
fi

# ── Determine which arrays to check ──────────────────────────────────────────
if [[ $# -gt 0 ]]; then
  ARRAYS=("$@")
else
  # Auto-detect all active md arrays from /proc/mdstat
  mapfile -t ARRAYS < <(grep -oP '^md\d+' /proc/mdstat | sed 's|^|/dev/|' | sort)
fi

if [[ ${#ARRAYS[@]} -eq 0 ]]; then
  echo "No active md arrays found. Nothing to monitor."
  exit 0
fi

# ── Print mdstat overview ─────────────────────────────────────────────────────
echo "============================================================"
echo " /proc/mdstat overview"
echo "============================================================"
cat /proc/mdstat
echo ""

# ── Track overall health ──────────────────────────────────────────────────────
DEGRADED=()
RESYNCING=()
CLEAN=()

# ── Check each array ──────────────────────────────────────────────────────────
for ARRAY in "${ARRAYS[@]}"; do
  if [[ ! -b "$ARRAY" ]]; then
    echo -e "${YELLOW}WARN${NC}: $ARRAY is not a block device — skipping"
    continue
  fi

  echo "============================================================"
  echo " $ARRAY — detail"
  echo "============================================================"

  # Capture full detail output
  DETAIL=$(mdadm --detail "$ARRAY" 2>&1)
  echo "$DETAIL"
  echo ""

  # Extract state line
  STATE=$(echo "$DETAIL" | grep -i 'State :' | head -1 | awk -F': ' '{print $2}' | xargs)

  # Extract the bitmap indicator line like [UUUUUU] or [UUU_UU]
  BITMAP=$(echo "$DETAIL" | grep -oP '\[U*_*U*\]' | head -1 || true)

  # Evaluate state
  if echo "$STATE" | grep -qi 'degraded'; then
    DEGRADED+=("$ARRAY (state: $STATE, bitmap: ${BITMAP:-unknown})")
  elif echo "$STATE" | grep -qiE 'resyncing|recovering|reshape'; then
    RESYNCING+=("$ARRAY (state: $STATE)")
  else
    CLEAN+=("$ARRAY (state: $STATE)")
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo "============================================================"
echo " Health Summary"
echo "============================================================"

if [[ ${#CLEAN[@]} -gt 0 ]]; then
  for a in "${CLEAN[@]}"; do
    echo -e "${GREEN}OK   ${NC} $a"
  done
fi

if [[ ${#RESYNCING[@]} -gt 0 ]]; then
  for a in "${RESYNCING[@]}"; do
    echo -e "${YELLOW}SYNC ${NC} $a"
  done
fi

if [[ ${#DEGRADED[@]} -gt 0 ]]; then
  echo ""
  echo -e "${RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
  echo -e "${RED}!! WARNING: DEGRADED ARRAY DETECTED                     !!${NC}"
  echo -e "${RED}!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!${NC}"
  for a in "${DEGRADED[@]}"; do
    echo -e "${RED}FAIL ${NC} $a"
  done
  echo ""
  echo "Action required:"
  echo "  1. Identify the failed drive: mdadm --detail <array>"
  echo "  2. Check SMART status: smartctl -a /dev/sdX"
  echo "  3. Replace the failed drive and add it back:"
  echo "     mdadm --manage <array> --add /dev/sdX"
  echo "  4. Monitor rebuild: watch cat /proc/mdstat"
  echo ""
  echo "For nested arrays (RAID 50/60): only the affected sub-array"
  echo "is rebuilding. The other sub-array continues serving data."
  echo ""
  exit 2
fi

if [[ ${#RESYNCING[@]} -gt 0 ]]; then
  echo ""
  echo "Note: One or more arrays are resyncing. This is normal after"
  echo "a drive replacement or system reboot. Monitor progress:"
  echo "  watch cat /proc/mdstat"
  exit 1
fi

echo ""
echo -e "${GREEN}All arrays are healthy.${NC}"
exit 0
