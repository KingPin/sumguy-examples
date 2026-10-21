# LittleLink vs LinkStack: self-hosted link-in-bio pages

Three ways to replace Linktree with something you host. Companion files for [LittleLink vs LinkStack: Ditch Linktree](https://sumguy.com/littlelink-vs-linkstack/).

| Directory | What it runs | Default port |
| --- | --- | --- |
| `littlelink/` | LittleLink v3.11.0 (static HTML/CSS) served by Caddy | 8080 |
| `linkstack/` | LinkStack 4.8.6 (PHP/Laravel, admin panel) | 8190 (HTTP), 8191 (HTTPS) |
| `littlelink-server/` | LittleLink-Server (Next.js, env-var config) | 8082 |

## Prerequisites and tested versions

- Docker 29.8.2 with Compose, and `git` (for the LittleLink fetch).
- `caddy:2-alpine`, Caddy v2.11.7 when tested
- LittleLink v3.11.0 (tag, fetched by script)
- `linkstackorg/linkstack:latest`, LinkStack 4.8.6 inside
- `ghcr.io/timothystewart6/littlelink-server:latest` (tested October 2026)

## Run

LittleLink (edit `site/index.html` after the fetch):

```bash
cd littlelink
./fetch.sh
docker compose up -d
curl -I http://localhost:8080/
```

For a real domain, set `SITE_ADDRESS=links.example.com` and publish port 443 (uncomment the line in `compose.yaml`). Caddy then gets a certificate on its own.

LinkStack (open `http://localhost:8190/` and finish the setup wizard):

```bash
cd linkstack
docker compose up -d
```

LittleLink-Server (edit the env vars, then restart):

```bash
cd littlelink-server
docker compose up -d
```

Change a host port with `HTTP_PORT=18080 docker compose up -d`. Remove a stack and its volumes with `docker compose down -v`.

All domains and names are placeholders (`links.example.com`).
