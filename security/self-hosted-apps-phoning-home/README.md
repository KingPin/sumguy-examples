# Catch Your Self-Hosted Apps Phoning Home

Working files for auditing and blocking outbound calls from a Docker home lab:
a per-container DNS audit trail, an allowlisting egress proxy, and a
`DOCKER-USER` egress rule set.

Article: https://sumguy.com/self-hosted-apps-phoning-home/

## What's here

```
audit/compose.yaml          # AdGuard Home on the apps' network, static IP, per-container query log
egress-proxy/compose.yaml   # app on an internal network, Squid as its only way out
egress-proxy/squid.conf     # domain allowlist
docker-user-egress.sh       # log + drop outbound traffic from one subnet (iptables backend)
```

## Prerequisites

- Docker Engine with Compose v2. Tested on Docker 29.x with the default iptables firewall backend.
- `docker-user-egress.sh` needs root and the iptables backend. Check with
  `docker info | grep -i firewall`. With the experimental nftables backend,
  Docker ignores `DOCKER-USER`; write your own nftables chain instead.

## How to run it

1. Audit: `cd audit && docker compose up -d`, open `http://<host>:3000`, finish
   the wizard (keep the admin port at 3000), then read the query log by client.
   Point your own app services at `dns: [172.20.0.2]` on the same network.
2. Egress proxy: `cd egress-proxy && docker compose up -d`, then
   `docker compose exec app curl -sI https://acme-v02.api.letsencrypt.org/directory`
   (allowed) and `docker compose exec app curl -sI https://example.com` (403 from Squid).
3. Firewall: `sudo SUBNET=172.20.0.0/24 RESOLVER=192.168.1.2 ./docker-user-egress.sh`,
   then `journalctl -k | grep egress-drop`. Rules are IPv4 only and do not survive
   a reboot; repeat with `ip6tables` for IPv6 networks and persist with `iptables-save`.

Edit the subnet, resolver IP, and allowlist to match your network.
