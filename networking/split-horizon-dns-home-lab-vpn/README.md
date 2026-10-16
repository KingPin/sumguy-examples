# Split-horizon DNS for a home lab with a VPN

Companion files for [Split-Horizon DNS for a Home Lab VPN](https://sumguy.com/split-horizon-dns-home-lab-vpn/).

Same name, two answers: `jellyfin.home.example.com` resolves to a LAN IP for clients at home and on the VPN, and to your public record for everyone else.

## Files

- `docker-compose.yml`: Unbound resolver on port 53.
- `unbound/unbound.conf`: `local-zone` / `local-data` split-horizon config.
- `adguardhome-snippet.yaml`: the same idea as AdGuard Home DNS rewrites.
- `wg0-client.conf`: WireGuard client with `DNS =` and a split-tunnel `AllowedIPs`.

## Prerequisites

- Docker with Compose v2.
- A host on the LAN with a static IP (the examples use `192.168.10.2`). Free port 53 first (`systemd-resolved` often holds it).
- Replace `example.com` and the RFC1918 addresses with yours.

Tested versions (October 2026): Unbound 1.26.1 (`klutchell/unbound`), AdGuard Home v0.107.79.

## Run

```bash
docker compose up -d
dig @192.168.10.2 jellyfin.home.example.com +short   # expect 192.168.10.20
dig @192.168.10.2 jellyfin.home.example.com AAAA +short   # expect empty
```

Validate the config without starting the resolver:

```bash
docker run --rm -v "$PWD/unbound/unbound.conf:/etc/unbound/unbound.conf:ro" --entrypoint unbound-checkconf klutchell/unbound /etc/unbound/unbound.conf
```
