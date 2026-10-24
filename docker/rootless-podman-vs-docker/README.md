# Rootless Podman Quadlets vs Docker rootless mode

Companion files for [Rootless Podman Quadlets vs Docker](https://sumguy.com/rootless-podman-vs-docker/).

The same two apps (Uptime Kuma on port 3001, whoami on port 8081) run as an unprivileged user two ways:

- `podman/`: Quadlet files with `AutoUpdate=registry`, one shared network, one named volume.
- `docker/`: `compose.yaml` plus `setup-rootless.sh`, the documented rootless Docker install steps.

## Prerequisites

- A Linux host with systemd, cgroups v2, and an unprivileged user (examples use `alice`, UID 1000).
- `/etc/subuid` and `/etc/subgid` entries with at least 65,536 IDs for that user.
- Podman: current stable is 6.1.x (Podman 6 removed slirp4netns, CNI, and cgroups v1 support). Quadlet needs a Podman with the systemd generator installed.
- Docker: Docker Engine 29.x with the `docker-ce-rootless-extras` package, plus the `uidmap` package.

Tested/target versions as of October 2026: Podman 6.1.4, Docker Engine 29.9.2, RootlessKit v3.3.0.

## Run: Podman

```bash
mkdir -p ~/.config/containers/systemd
cp podman/* ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start uptime-kuma.service whoami.service
sudo loginctl enable-linger "$(whoami)"
systemctl --user enable --now podman-auto-update.timer
journalctl --user -u uptime-kuma.service
```

Preview what Quadlet generates (or see syntax errors) with `/usr/lib/systemd/system-generators/podman-system-generator --user --dryrun`.

## Run: Docker

```bash
./docker/setup-rootless.sh
docker compose -f docker/compose.yaml up -d
```

Docker has no built-in auto-update. Pull and recreate manually: `docker compose pull && docker compose up -d`.

Run only one stack at a time: both publish ports 3001 and 8081.
