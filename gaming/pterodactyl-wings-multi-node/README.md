# pterodactyl-wings-multi-node

Files for adding a second Wings node to an existing Pterodactyl Panel: an annotated node config, a per-node firewall script, a certificate script, and the official systemd unit.

Full writeup: [sumguy.com/pterodactyl-wings-multi-node/](https://sumguy.com/pterodactyl-wings-multi-node/)

## Files

- `config.example.yml`: an annotated `/etc/pterodactyl/config.yml` for node 2. The uuid and token are fake placeholders. It marks which keys the Panel writes and which stay local, and shows `api.ssl`, `trusted_proxies`, the SFTP block, and a `docker.network` override that moves the Wings bridge off `172.18.0.0/16`.
- `node-firewall.sh`: `ufw` rules for the daemon port (8080/tcp), SFTP (2022/tcp), and a game port range (tcp and udp). Ports are variables at the top.
- `certbot-node.sh`: issues a Let's Encrypt certificate for the node FQDN with certbot, standalone or manual DNS, and installs a certbot deploy hook that restarts Wings after each renewal.
- `wings.service`: the systemd unit exactly as the official Wings install docs give it.

## Prerequisites

- A working Panel (tested target: Pterodactyl Panel v1.15.2) served over HTTPS.
- A second Linux box with Docker, running Wings (tested target: v1.13.4). Panel and Wings should be on the same release line.
- An A record such as `node2.example.com` pointing at the node, reachable from players' browsers.
- Root access on the node. `ufw` for the firewall script, `certbot` for the certificate script.

## Use it

1. Create the node in the Panel (Nodes, Create New) with the FQDN, ports, and memory and disk figures.
2. Install Docker and the Wings binary per the official install docs, then copy `wings.service` to `/etc/systemd/system/`.
3. Get the certificate: `sudo ./certbot-node.sh node2.example.com standalone`.
4. Paste the Panel's generated config into `/etc/pterodactyl/config.yml`. Use `config.example.yml` as a map of what each key does, and do not paste its placeholder token.
5. Open the ports: `sudo GAME_RANGE=25565:25665 ./node-firewall.sh`.
6. Run `sudo systemctl enable --now wings`, and check that the node shows as online in the Panel.

## Notes

- If you change the `docker.network` subnet, run `systemctl stop wings && docker network rm pterodactyl_nw && systemctl start wings` so Wings recreates the network.
- Docker publishes container ports through its own iptables rules, ahead of `ufw`. Check game ports from outside the box.
