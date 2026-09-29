# linuxgsm-game-servers

Runnable configs for the two ways to run a LinuxGSM game server: the official Docker image, and bare metal with systemd plus cron. Both examples use Valheim (`vh` / `vhserver`) as the game, but the pattern is identical for any of the 140 servers LinuxGSM supports; just swap the shortname.

Full writeup: [sumguy.com/linuxgsm-game-servers/](https://sumguy.com/linuxgsm-game-servers/)

## Files

- `docker-compose.yml`: the official `gameservermanagers/gameserver:vh` image, host networking, one named volume for `/data`.
- `vhserver.service`: an optional systemd unit that wraps `./vhserver start` and `./vhserver stop` for the bare-metal path. LinuxGSM does not ship this itself; it is a convenience wrapper, not a replacement for LinuxGSM's own `monitor` command.
- `crontab-vhserver`: the cron lines LinuxGSM's own Valheim page recommends, for monitoring, game updates, and weekly LinuxGSM script updates.

## Prerequisites

- Docker 27.x and Compose v2 (tested with Docker 29.8.1 / Compose 5.5.1) for the container path.
- A Debian or Ubuntu box (Ubuntu 24.04 LTS or Debian 11 recommended) with `tmux` 1.6+ and `glibc` 2.15+ for the bare-metal path.
- A non-root user for the game server either way. LinuxGSM refuses to run a game server as root.

## Run it: Docker

```bash
docker compose up -d
docker compose logs -f vhserver
```

First run installs Valheim from scratch via SteamCMD inside the container; give it a few minutes. Run LinuxGSM commands against the running container with `docker exec`:

```bash
docker exec -it --user linuxgsm vhserver ./vhserver details
docker exec -it --user linuxgsm vhserver ./vhserver console
```

To edit the config, mount `/data` to a host path instead of the named volume, then edit `lgsm/config-lgsm/vhserver/vhserver.cfg` under that path and restart the container.

## Run it: bare metal

```bash
sudo adduser vhserver
sudo su - vhserver
curl -Lo linuxgsm.sh https://linuxgsm.sh && chmod +x linuxgsm.sh && bash linuxgsm.sh vhserver
./vhserver install
```

Install the cron lines:

```bash
crontab -e
# paste the contents of crontab-vhserver
```

Install the optional systemd unit:

```bash
sudo cp vhserver.service /etc/systemd/system/vhserver.service
sudo systemctl daemon-reload
sudo systemctl enable --now vhserver
```

Open the firewall (Valheim uses UDP `2456` for the game and `2457` for the Steam query port, one number up from whatever you set in `port=`):

```bash
sudo ufw allow 2456:2457/udp
```

## Validated

`docker compose config` runs clean against `docker-compose.yml` in this folder (Docker 29.8.1 / Compose 5.5.1), confirming the file parses and the image reference resolves. A full game download was not run as part of validation.
