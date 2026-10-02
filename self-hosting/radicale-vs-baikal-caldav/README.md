# Radicale vs Baikal: CalDAV that syncs

Two self-hosted CalDAV/CardDAV servers for a shared household calendar, plus a Caddy reverse proxy with the `.well-known` redirects clients need.

Article: https://sumguy.com/radicale-vs-baikal-caldav/

## What is here

| Path | Purpose |
| --- | --- |
| `radicale/compose.yaml` | Radicale 3.8.1 via `tomsquest/docker-radicale`, bound to localhost:5232 |
| `radicale/config/config` | htpasswd (bcrypt) auth, `from_file` rights, storage in `/data/collections` |
| `radicale/config/rights` | Per-user collections plus a shared `/household/` collection for `alice` and `bob` |
| `baikal/compose.yaml` | Baikal via `ckulka/baikal:nginx`, bound to localhost:8080 |
| `Caddyfile` | TLS, `.well-known` redirects, reverse proxy for either server |

## Prerequisites

- Docker with Compose v2
- A hostname with DNS pointing at your server (the examples use `calendar.example.com`)
- Caddy (or any reverse proxy that can issue real HTTPS certificates)
- `htpasswd` from `apache2-utils`/`httpd-tools`, or Docker (to run it from the `httpd` image)

Tested with: Radicale 3.8.1 (`tomsquest/docker-radicale:3.8.1.1`). The Radicale rights file was exercised with curl: both users could create and write in `/household/`, and an anonymous request got 401. The Baikal compose file passes `docker compose config`. The `ckulka/baikal` repo builds Baikal 0.10.1 at the time of writing, even though upstream Baikal is at 0.12.1. The image README calls the `nginx` tag worth checking out for its smaller size.

## Run Radicale

```bash
cd radicale
docker run --rm httpd:2 htpasswd -nbB alice 'change-me' | grep . > config/users
docker run --rm httpd:2 htpasswd -nbB bob   'change-me' | grep . >> config/users
docker compose up -d
```

Create the shared collection once. The parent `/household/` must exist before the calendar:

```bash
curl -u alice -X MKCOL https://calendar.example.com/household/
curl -u alice -X MKCOL https://calendar.example.com/household/family --data \
'<?xml version="1.0"?><create xmlns="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav"><set><prop><resourcetype><collection/><C:calendar/></resourcetype></prop></set></create>'
```

Clients then use the full calendar URL `https://calendar.example.com/household/family/` as a second account or calendar.

## Run Baikal

```bash
cd baikal
docker compose up -d
```

Open `http://localhost:8080/` for the first-run installer, then `/admin/` to create users and calendars.

## Reverse proxy

Copy the block that matches your server from `Caddyfile`, change the hostname, and reload Caddy. Clients need HTTPS. Apple devices refuse to send credentials over plain HTTP.

## Backups

- Radicale: back up `radicale/data/` and `radicale/config/`.
- Baikal: back up the `config` and `data` volumes (`/var/www/baikal/config` and `/var/www/baikal/Specific`).
