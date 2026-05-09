#!/usr/bin/env bash
# scrub-cron.sh
# Monthly RAID scrub script for mdadm arrays.
# Iterates every active md device, triggers a consistency check,
# monitors until complete, logs mismatch counts, and emails if non-zero.
#
# Install: copy to /etc/cron.monthly/mdadm-scrub, chmod +x
# Requires: mdadm, /proc/mdstat, optionally mail(1) for alerts
#
# Companion to: https://sumguy.com/posts/mdadm-day-2-operations/

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
MAILTO="root"                        # Email address for mismatch alerts
LOG_TAG="mdadm-scrub"               # syslog/logger tag
CHECK_INTERVAL=30                   # Seconds between progress polls
MAX_WAIT_HOURS=48                   # Bail out if scrub takes longer than this

# ── Helpers ───────────────────────────────────────────────────────────────────
log() {
  logger -t "$LOG_TAG" "$*"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

send_alert() {
  local subject="$1"
  local body="$2"
  if command -v mail &>/dev/null; then
    echo "$body" | mail -s "$subject" "$MAILTO"
    log "Alert sent to $MAILTO: $subject"
  else
    log "ALERT (no mail command): $subject — $body"
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run as root." >&2
  exit 1
fi

log "Starting monthly RAID scrub."

# Collect active md devices from /proc/mdstat
MD_DEVICES=()
while IFS= read -r line; do
  if [[ "$line" =~ ^(md[0-9]+) ]]; then
    MD_DEVICES+=("${BASH_REMATCH[1]}")
  fi
done < /proc/mdstat

if [[ ${#MD_DEVICES[@]} -eq 0 ]]; then
  log "No active md devices found. Nothing to scrub."
  exit 0
fi

log "Found ${#MD_DEVICES[@]} array(s): ${MD_DEVICES[*]}"

GLOBAL_MISMATCHES=0
FAILED_ARRAYS=()

for md in "${MD_DEVICES[@]}"; do
  SYS_PATH="/sys/block/${md}/md"

  if [[ ! -d "$SYS_PATH" ]]; then
    log "WARN: $md — no sysfs path at $SYS_PATH, skipping."
    continue
  fi

  RAID_LEVEL=$(cat "${SYS_PATH}/level" 2>/dev/null || echo "unknown")
  log "$md ($RAID_LEVEL): Triggering check..."

  # Trigger the check
  echo check > "${SYS_PATH}/sync_action"

  # Wait for it to complete
  MAX_POLLS=$(( MAX_WAIT_HOURS * 3600 / CHECK_INTERVAL ))
  POLLS=0
  while [[ "$(cat "${SYS_PATH}/sync_action" 2>/dev/null)" != "idle" ]]; do
    POLLS=$(( POLLS + 1 ))
    if [[ $POLLS -gt $MAX_POLLS ]]; then
      log "ERROR: $md scrub exceeded ${MAX_WAIT_HOURS}h timeout. Stopping check."
      echo idle > "${SYS_PATH}/sync_action" 2>/dev/null || true
      FAILED_ARRAYS+=("$md (timeout)")
      break
    fi

    # Log progress every 10 polls
    if (( POLLS % 10 == 0 )); then
      COMPLETED=$(cat "${SYS_PATH}/sync_completed" 2>/dev/null || echo "?")
      TOTAL=$(cat "${SYS_PATH}/sync_max" 2>/dev/null || echo "?")
      log "$md: check in progress ($COMPLETED / $TOTAL sectors)"
    fi

    sleep "$CHECK_INTERVAL"
  done

  MISMATCH=$(cat "${SYS_PATH}/mismatch_cnt" 2>/dev/null || echo "0")
  log "$md: check complete. Mismatch count: $MISMATCH"

  if [[ "$MISMATCH" -gt 0 ]]; then
    GLOBAL_MISMATCHES=$(( GLOBAL_MISMATCHES + MISMATCH ))
    log "WARN: $md has $MISMATCH mismatches. Investigation recommended."
    send_alert \
      "[RAID] Scrub mismatch on $md — $(hostname)" \
      "Array: $md ($RAID_LEVEL)\nHost: $(hostname)\nDate: $(date)\nMismatch count: $MISMATCH\n\nCheck mdadm --detail /dev/$md and review dmesg for errors.\nNote: mdadm corrects mismatches in RAID 5/6 automatically but non-zero counts warrant investigation."
  fi
done

# Summary
log "Scrub complete. Arrays checked: ${#MD_DEVICES[@]}. Total mismatches: $GLOBAL_MISMATCHES."

if [[ ${#FAILED_ARRAYS[@]} -gt 0 ]]; then
  log "Arrays with issues: ${FAILED_ARRAYS[*]}"
  send_alert \
    "[RAID] Scrub issues on $(hostname)" \
    "The following arrays had problems during monthly scrub: ${FAILED_ARRAYS[*]}\n\nCheck system logs for details."
  exit 1
fi

exit 0
