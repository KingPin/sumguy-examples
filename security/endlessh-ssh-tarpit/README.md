# Endlessh SSH tarpit examples

Companion files for [Endlessh: Is an SSH Tarpit Worth It?](https://sumguy.com/endlessh-ssh-tarpit/).

## What is here

- `compose.yaml`: endlessh-go on host port 22 (container port 2222), Prometheus metrics on `127.0.0.1:2112`, plus a small Prometheus that scrapes it.
- `prometheus.yml`: scrape config for the compose file.
- `endlessh.config`: example config for the C Endlessh (`/etc/endlessh/config`).
- `endlessh-override.conf`: systemd drop-in so the C Endlessh can bind a port below 1024.

## Prerequisites and versions

- Docker with the Compose plugin.
- endlessh-go 2026.0730.0 and Prometheus v3.16.0 (both pinned in `compose.yaml`).
- Debian `endlessh` 1.1-5 (bookworm) or 1.1-5.1 (trixie) for the C version (`sudo apt install endlessh`).

## Move sshd first

The compose file publishes host port 22. If your real sshd still listens there, the container fails to start, or worse, you lock yourself out later.

1. Open the firewall for the new sshd port.
2. Set `Port 2200` (or any free port) in `/etc/ssh/sshd_config`.
3. On Ubuntu 24.04 and newer, run `sudo systemctl daemon-reload && sudo systemctl restart ssh.socket`. Elsewhere, restart `ssh` (Debian/Ubuntu) or `sshd` (RHEL-family).
4. Keep your current session open and log in from a second terminal on the new port.
5. On RHEL-family systems, also run `sudo semanage port -a -t ssh_port_t -p tcp 2200`.

## Run

```bash
docker compose up -d
docker compose logs -f endlessh
ssh -p 22 192.0.2.10   # hangs by design
curl -s http://127.0.0.1:2112/metrics | grep endlessh_
```

For the C version, copy `endlessh.config` to `/etc/endlessh/config`, install the drop-in with `sudo systemctl edit endlessh`, then `sudo systemctl restart endlessh`.

## Notes

- Grafana dashboard ID 15156 works with these metrics.
- A tarpit is telemetry, not a security control. Use key-only auth.
