#!/usr/bin/env bash
# ufw rules for a Wings node. Run as root on each node.
# Edit the variables, then: sudo ./node-firewall.sh
set -euo pipefail

SSH_PORT="${SSH_PORT:-22}"
DAEMON_PORT="${DAEMON_PORT:-8080}"   # Node "Daemon Port" in the Panel
SFTP_PORT="${SFTP_PORT:-2022}"       # Node "Daemon SFTP Port" in the Panel
GAME_RANGE="${GAME_RANGE:-25565:25665}"  # must match the allocations you create

# Browsers connect straight to the daemon port for the console, uploads, and downloads,
# so it cannot be limited to the Panel IP. Other nodes also connect here
# during server transfers.
ufw allow "${SSH_PORT}/tcp"
ufw allow "${DAEMON_PORT}/tcp"
ufw allow "${SFTP_PORT}/tcp"
ufw allow "${GAME_RANGE}/tcp"
ufw allow "${GAME_RANGE}/udp"

# Gotcha: ports that Docker publishes go through Docker's own iptables
# rules, which are evaluated before ufw. Treat these rules as documentation
# for the host services (Wings API, SFTP) and verify game ports from outside.
ufw --force enable
ufw status verbose
