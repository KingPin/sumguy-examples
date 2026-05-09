#!/usr/bin/env bash
# cpu-overhead-test.sh
# Measures CPU overhead of software RAID 6 parity on a modern system.
# Uses loop devices only — never touches real disks.
#
# Requires: mdadm, fio, sysstat (mpstat), root/sudo
# Usage: sudo bash cpu-overhead-test.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Safety: refuse to run if somehow invoked with real disk arguments
# ---------------------------------------------------------------------------
for arg in "$@"; do
    if [[ "$arg" =~ ^/dev/(sd|nvme|hd) ]]; then
        echo "ERROR: This script only uses loop devices. Real disk paths are not accepted." >&2
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
ARRAY_DEVICE="/dev/md99"
MOUNT_POINT="/tmp/raid6-overhead-test"
LOOP_DIR="/tmp/raid6-loop-backing"
NUM_DISKS=8
DISK_SIZE_MB=256
FIO_RUNTIME=20     # seconds per workload
SCRUB_WAIT=30      # seconds to capture mpstat during scrub
MPSTAT_INTERVAL=2  # seconds between mpstat samples

# Track created resources for cleanup
LOOP_DEVICES=()

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
check_deps() {
    local missing=()
    for cmd in mdadm fio mpstat losetup mkfs.ext4; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Missing required tools: ${missing[*]}" >&2
        echo "Install with: apt install mdadm fio sysstat util-linux e2fsprogs" >&2
        exit 1
    fi

    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: This script must run as root (or via sudo)." >&2
        exit 1
    fi

    if [[ -e "$ARRAY_DEVICE" ]]; then
        echo "ERROR: $ARRAY_DEVICE already exists. Is a test array already running?" >&2
        echo "If so, clean it up first: mdadm --stop $ARRAY_DEVICE" >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Cleanup — always runs, even on error
# ---------------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    echo ""
    echo "--- Cleaning up ---"

    # Unmount
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        umount "$MOUNT_POINT" || true
    fi

    # Stop the array
    if [[ -e "$ARRAY_DEVICE" ]]; then
        mdadm --stop "$ARRAY_DEVICE" 2>/dev/null || true
    fi

    # Detach loop devices
    for loop in "${LOOP_DEVICES[@]}"; do
        if losetup "$loop" &>/dev/null; then
            losetup -d "$loop" 2>/dev/null || true
        fi
    done

    # Remove backing files and dirs
    rm -rf "$LOOP_DIR" "$MOUNT_POINT"

    if [[ $exit_code -eq 0 ]]; then
        echo "Cleanup complete."
    else
        echo "Cleanup complete (script exited with error $exit_code)."
    fi
}

trap cleanup EXIT

# ---------------------------------------------------------------------------
# Setup: create loop device backing files and attach them
# ---------------------------------------------------------------------------
setup_loop_devices() {
    echo "--- Creating $NUM_DISKS loop devices (${DISK_SIZE_MB}MB each) ---"
    mkdir -p "$LOOP_DIR"

    for i in $(seq 0 $((NUM_DISKS - 1))); do
        local backing_file="$LOOP_DIR/disk${i}.img"
        # Create sparse file
        truncate -s "${DISK_SIZE_MB}M" "$backing_file"
        # Attach loop device
        local loop_dev
        loop_dev=$(losetup --find --show "$backing_file")
        LOOP_DEVICES+=("$loop_dev")
        echo "  Created $loop_dev <- $backing_file"
    done
}

# ---------------------------------------------------------------------------
# Assemble RAID 6 array
# ---------------------------------------------------------------------------
create_array() {
    echo ""
    echo "--- Assembling RAID 6 across ${#LOOP_DEVICES[@]} devices ---"
    echo "  Devices: ${LOOP_DEVICES[*]}"

    # --force and --assume-clean skip full initialization (safe for test arrays)
    mdadm --create "$ARRAY_DEVICE" \
        --level=6 \
        --raid-devices="$NUM_DISKS" \
        --chunk=512 \
        --assume-clean \
        --force \
        "${LOOP_DEVICES[@]}" <<< "y"

    echo ""
    echo "Array status:"
    cat /proc/mdstat

    echo ""
    echo "Creating ext4 filesystem on $ARRAY_DEVICE..."
    mkfs.ext4 -q -F "$ARRAY_DEVICE"

    mkdir -p "$MOUNT_POINT"
    mount "$ARRAY_DEVICE" "$MOUNT_POINT"
    echo "Mounted at $MOUNT_POINT"
}

# ---------------------------------------------------------------------------
# Run fio workloads and capture CPU
# ---------------------------------------------------------------------------
run_fio_workload() {
    local label="$1"
    local rw="$2"
    local bs="$3"
    local qd="$4"

    echo ""
    echo "--- fio: $label ---"
    echo "  rw=$rw bs=$bs iodepth=$qd runtime=${FIO_RUNTIME}s"

    # Start mpstat in background
    local mpstat_log="$LOOP_DIR/mpstat_${label// /_}.log"
    mpstat -u "$MPSTAT_INTERVAL" $((FIO_RUNTIME / MPSTAT_INTERVAL)) \
        > "$mpstat_log" 2>&1 &
    local mpstat_pid=$!

    # Run fio
    fio \
        --name="$label" \
        --filename="$MOUNT_POINT/testfile" \
        --rw="$rw" \
        --bs="$bs" \
        --iodepth="$qd" \
        --ioengine=libaio \
        --direct=1 \
        --size="$((DISK_SIZE_MB * (NUM_DISKS - 2) / 2))M" \
        --runtime="${FIO_RUNTIME}" \
        --time_based \
        --group_reporting \
        --output-format=terse \
        --terse-version=3 2>/dev/null | \
    awk -F';' '{
        printf "  Read:  %s IOPS, %s KB/s\n", $8, $7
        printf "  Write: %s IOPS, %s KB/s\n", $49, $48
    }'

    wait "$mpstat_pid" 2>/dev/null || true

    # Parse average CPU usage (idle column = 12th field in mpstat output)
    local avg_idle avg_usr avg_sys
    avg_idle=$(awk '/^[0-9]/ && !/CPU/ {sum+=$NF; count++} END {if(count>0) printf "%.1f", sum/count}' "$mpstat_log")
    avg_usr=$(awk '/^[0-9]/ && !/CPU/ {sum+=$3; count++} END {if(count>0) printf "%.1f", sum/count}' "$mpstat_log")
    avg_sys=$(awk '/^[0-9]/ && !/CPU/ {sum+=$5; count++} END {if(count>0) printf "%.1f", sum/count}' "$mpstat_log")

    echo "  CPU during workload: ${avg_usr}% user, ${avg_sys}% sys, ${avg_idle}% idle"
    echo "$label|${avg_usr}|${avg_sys}|${avg_idle}" >> "$LOOP_DIR/cpu_summary.tsv"
}

# ---------------------------------------------------------------------------
# Trigger a scrub and measure CPU
# ---------------------------------------------------------------------------
run_scrub() {
    echo ""
    echo "--- Scrub test (${SCRUB_WAIT}s capture) ---"

    # Find the md device name (without /dev/ prefix)
    local md_name
    md_name=$(basename "$ARRAY_DEVICE")

    # Start mpstat
    local mpstat_log="$LOOP_DIR/mpstat_scrub.log"
    mpstat -u "$MPSTAT_INTERVAL" $((SCRUB_WAIT / MPSTAT_INTERVAL)) \
        > "$mpstat_log" 2>&1 &
    local mpstat_pid=$!

    # Trigger check
    echo "check" > "/sys/block/${md_name}/md/sync_action" 2>/dev/null || {
        echo "  (Could not trigger scrub via sysfs — skipping)"
        wait "$mpstat_pid" 2>/dev/null || true
        return
    }
    echo "  Scrub triggered. Capturing CPU for ${SCRUB_WAIT}s..."

    wait "$mpstat_pid" 2>/dev/null || true

    local sync_speed
    sync_speed=$(cat "/sys/block/${md_name}/md/sync_speed" 2>/dev/null || echo "unknown")

    local avg_usr avg_sys avg_idle
    avg_usr=$(awk '/^[0-9]/ && !/CPU/ {sum+=$3; count++} END {if(count>0) printf "%.1f", sum/count}' "$mpstat_log")
    avg_sys=$(awk '/^[0-9]/ && !/CPU/ {sum+=$5; count++} END {if(count>0) printf "%.1f", sum/count}' "$mpstat_log")
    avg_idle=$(awk '/^[0-9]/ && !/CPU/ {sum+=$NF; count++} END {if(count>0) printf "%.1f", sum/count}' "$mpstat_log")

    echo "  Sync speed: ${sync_speed} KB/s"
    echo "  CPU during scrub: ${avg_usr}% user, ${avg_sys}% sys, ${avg_idle}% idle"
    echo "scrub|${avg_usr}|${avg_sys}|${avg_idle}" >> "$LOOP_DIR/cpu_summary.tsv"
}

# ---------------------------------------------------------------------------
# Print summary
# ---------------------------------------------------------------------------
print_summary() {
    echo ""
    echo "========================================"
    echo "  RAID 6 CPU Overhead Test — Summary"
    echo "========================================"
    echo ""
    echo "  Array:      $ARRAY_DEVICE"
    echo "  Level:      RAID 6"
    echo "  Devices:    $NUM_DISKS (${DISK_SIZE_MB}MB loop devices)"
    echo "  Usable:     $((DISK_SIZE_MB * (NUM_DISKS - 2)))MB (N-2 efficiency)"
    echo ""
    echo "  CPU Measurements (system average across all cores):"
    echo ""
    printf "  %-30s %8s %8s %8s\n" "Workload" "User%" "Sys%" "Idle%"
    printf "  %-30s %8s %8s %8s\n" "--------" "-----" "----" "-----"

    if [[ -f "$LOOP_DIR/cpu_summary.tsv" ]]; then
        while IFS='|' read -r label usr sys idle; do
            printf "  %-30s %8s %8s %8s\n" "$label" "$usr" "$sys" "$idle"
        done < "$LOOP_DIR/cpu_summary.tsv"
    fi

    echo ""
    echo "  Note: Loop devices on a RAM-backed tmpfs will show lower CPU than"
    echo "  real spinning disks (less wait time). The parity calculation cost"
    echo "  is what matters — and it's small."
    echo ""
    echo "  See: https://sumguy.com/posts/hardware-vs-software-raid/"
    echo "========================================"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    echo "========================================"
    echo "  RAID 6 CPU Overhead Test"
    echo "  Loop devices only — no real disks"
    echo "========================================"
    echo ""

    check_deps
    setup_loop_devices
    create_array

    # Create an initial test file for fio to work with
    dd if=/dev/zero of="$MOUNT_POINT/testfile" \
        bs=1M count="$((DISK_SIZE_MB * (NUM_DISKS - 2) / 2))" \
        2>/dev/null

    # Workloads
    run_fio_workload "seq-write-128k"   "write"     "128k" 8
    run_fio_workload "seq-read-128k"    "read"      "128k" 8
    run_fio_workload "rand-write-4k"    "randwrite"  "4k"  16
    run_fio_workload "rand-read-4k"     "randread"   "4k"  16

    run_scrub

    print_summary
}

main "$@"
