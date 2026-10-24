#!/usr/bin/env bash
# Documented rootless Docker install for a package-based Docker Engine install.
# Run as the unprivileged user (for example alice, UID 1000), not as root.
set -euo pipefail

# 1. Prerequisites: newuidmap/newgidmap (uidmap package) and 65,536 subordinate IDs.
command -v newuidmap >/dev/null || { echo "install the uidmap package first"; exit 1; }
grep "^$(whoami):" /etc/subuid /etc/subgid

# 2. Install the per-user daemon (creates ~/.config/systemd/user/docker.service
#    and a CLI context named "rootless").
dockerd-rootless-setuptool.sh install

# 3. Start on boot without a login session.
systemctl --user enable --now docker
sudo loginctl enable-linger "$(whoami)"

# 4. Confirm the client talks to the rootless daemon.
docker info --format '{{.SecurityOptions}}' | grep rootless
echo "optional: export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock"
