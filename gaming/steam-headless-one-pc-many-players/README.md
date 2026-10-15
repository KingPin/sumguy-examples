# Steam Headless: one PC, many players

Three Steam Headless v2 containers ("seats") on one Linux host. Each seat is its own KDE Wayland desktop with Steam and Sunshine, reachable with Moonlight or the browser UI on port 8483. Write-up: https://sumguy.com/steam-headless-one-pc-many-players/

## Files

- `compose.yaml`: three seats, macvlan network, shared `/mnt/games`, provisioning-password secret.
- `host-setup.sh`: inotify sysctl plus the host macvlan shim.
- `.env.example`: the provisioning password placeholder.

## Prerequisites and tested versions

- Image `josh5/steam-headless:2.44.20261004.1`
- NVIDIA driver 595.99.02 on an RTX 3070 Laptop (8 GB), `nvidia_drm.modeset=Y`
- Docker 29.8.0, Compose v5.5.1
- Wired Ethernet (macvlan over Wi-Fi generally fails) and a switch that allows several MACs per port.

Our test ran two seats with bridge networking and localhost ports. The multi-seat macvlan layout here follows the official Steam Headless docs and was not run end to end. We did not test Moonlight over macvlan, real games, or a Steam login.

## Run

1. Edit the addresses, `parent` interface and render nodes (`ls -l /sys/class/drm/renderD*/device`) in `compose.yaml` and `host-setup.sh`.
2. For NVIDIA, uncomment `runtime: nvidia` and the two `NVIDIA_*` variables.
3. `sudo ./host-setup.sh`
4. `cp .env.example .env`, set the password, `chmod 600 .env`, then `set -a; . ./.env; set +a`
5. `mkdir -p homes/parent homes/kid1 homes/kid2` (so Docker doesn't create them as root)
6. `docker compose up -d`
7. Open `https://192.168.50.193:8483` (and `.194`, `.195`) or pair Moonlight to those IPs.

The host shim does not persist across reboots. Do not expose these ports to the internet.
