#!/usr/bin/env bash
# snapraid-sync.sh — Nightly SnapRAID sync with sanity checks
#
# See: https://sumguy.com/posts/snapraid-parity-without-realtime/
#
# Install: sudo cp sync-cron.sh /usr/local/bin/snapraid-sync.sh
#          sudo chmod +x /usr/local/bin/snapraid-sync.sh
#
# Cron (run as root, nightly at 2 AM):
#   0 2 * * * /usr/local/bin/snapraid-sync.sh
#
# What this does:
#   1. Runs 'snapraid diff' to check how much changed since last sync
#   2. Aborts if too many deletions are detected (configurable threshold)
#   3. Runs 'snapraid sync' if the diff looks sane
#   4. Runs 'snapraid scrub' on Sundays (5% of data per week)
#   5. Logs everything to syslog (readable via journalctl or /var/log/syslog)

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Maximum number of deleted files before the script aborts instead of syncing.
# SnapRAID treats a mass deletion as potentially dangerous — your data might
# have been accidentally wiped rather than intentionally removed. Tune this
# to match how many files you typically delete between syncs.
MAX_DELETE_THRESHOLD=50

# Scrub percentage per run — run on a specific day of the week (0=Sun, 6=Sat)
SCRUB_PERCENT=5
SCRUB_DAY=0  # Sunday

# SnapRAID binary (usually /usr/bin/snapraid after apt install)
SNAPRAID_BIN="$(command -v snapraid)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log() {
    logger -t snapraid-sync "$*"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [snapraid-sync] $*"
}

abort() {
    log "ABORT: $*"
    exit 1
}

# ---------------------------------------------------------------------------
# Sanity check
# ---------------------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    abort "Must run as root (use sudo or root crontab)"
fi

if [[ -z "${SNAPRAID_BIN}" ]]; then
    abort "snapraid not found in PATH"
fi

# ---------------------------------------------------------------------------
# Diff check — inspect what changed since last sync
# ---------------------------------------------------------------------------

log "Running snapraid diff..."

# Capture diff output; don't let set -e kill us on non-zero exit from diff
DIFF_OUTPUT="$("${SNAPRAID_BIN}" diff 2>&1)" || true

log "Diff output:"
echo "${DIFF_OUTPUT}" | logger -t snapraid-diff || true
echo "${DIFF_OUTPUT}"

# Parse deletion count from diff output
DELETED=$(echo "${DIFF_OUTPUT}" | grep -E '^ {0,}[0-9]+ removed$' | awk '{print $1}' || echo "0")
DELETED="${DELETED:-0}"

log "Files removed since last sync: ${DELETED}"

if [[ "${DELETED}" -gt "${MAX_DELETE_THRESHOLD}" ]]; then
    abort "${DELETED} deletions detected — exceeds threshold of ${MAX_DELETE_THRESHOLD}. Skipping sync. Verify intentional and re-run manually: snapraid sync"
fi

# ---------------------------------------------------------------------------
# Sync
# ---------------------------------------------------------------------------

log "Starting snapraid sync..."

if "${SNAPRAID_BIN}" sync; then
    log "Sync completed successfully."
else
    abort "snapraid sync failed — check output above."
fi

# ---------------------------------------------------------------------------
# Weekly scrub (on SCRUB_DAY)
# ---------------------------------------------------------------------------

TODAY=$(date +%w)  # 0=Sunday, 6=Saturday

if [[ "${TODAY}" -eq "${SCRUB_DAY}" ]]; then
    log "Sunday — running snapraid scrub (${SCRUB_PERCENT}% of data)..."
    if "${SNAPRAID_BIN}" scrub -p "${SCRUB_PERCENT}"; then
        log "Scrub completed successfully."
    else
        # Scrub failure is not fatal — log it and move on
        log "WARNING: snapraid scrub reported errors. Run 'snapraid status' to investigate."
    fi
else
    log "Not scrub day (today=${TODAY}, scrub day=${SCRUB_DAY}) — skipping scrub."
fi

log "Done."
