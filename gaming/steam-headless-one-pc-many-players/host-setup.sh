#!/usr/bin/env bash
# Host prep for the multi-seat layout. Run as root. Safe to re-run.
set -euo pipefail

PARENT_IF=eth0
SHIM_IF=macvlan-shim
SHIM_IP=192.168.50.222          # must match aux_addresses in compose.yaml
SEAT_RANGE=192.168.50.192/27    # must match ip_range in compose.yaml
INOTIFY_INSTANCES=1024          # 1024 for 2-3 seats, 3072 for 4-8, 8192+ for 9+

echo "fs.inotify.max_user_instances = ${INOTIFY_INSTANCES}" > /etc/sysctl.d/99-steam-headless.conf
sysctl --system >/dev/null

if ! ip link show "$SHIM_IF" >/dev/null 2>&1; then
  ip link add "$SHIM_IF" link "$PARENT_IF" type macvlan mode bridge
fi
ip addr replace "${SHIM_IP}/32" dev "$SHIM_IF"
ip link set "$SHIM_IF" up
ip route replace "$SEAT_RANGE" dev "$SHIM_IF"

echo "nvidia_drm.modeset: $(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null || echo 'n/a (not NVIDIA)')"
ls -l /sys/class/drm/renderD*/device
# The shim does not survive a reboot. Persist it with your network manager.
