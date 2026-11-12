# Penpot self-hosted (Docker Compose)

A small, pinned Penpot stack for trying the open source Figma alternative on your own server. It follows the official `docker/images/docker-compose.yaml` from the Penpot repository at release 2.19.1, with these changes: secrets, the host port, the public URL and the cookie flag come from `.env`, the image default is pinned to 2.19.1 (the official file at that tag still defaults to 2.18), the demo `penpot-mailpit` container and the `enable-smtp` flag are removed, and `PENPOT_TELEMETRY_ENABLED` is set to `"false"`.

Article: https://sumguy.com/penpot-self-hosted-figma-alternative/

## What runs

Seven containers: `penpot-frontend` (nginx, serves the app and proxies the API), `penpot-backend`, `penpot-exporter`, `penpot-admin-console`, `penpot-mcp`, `penpot-postgres` (PostgreSQL 15) and `penpot-valkey` (Valkey 8.1). Uploaded assets live in the `penpot_assets` volume, the database in `penpot_postgres_v15`. Compose prefixes both with the project name (the folder name by default), so check `docker volume ls` before you point other tools at them.

## Prerequisites and tested versions

- Docker Engine 29 with the Compose plugin
- About 3 GiB of free RAM (see below)
- Tested: Penpot 2.19.1, `postgres:15`, `valkey/valkey:8.1`, on Linux with Docker 29

## Run it

```bash
cp .env.example .env
sed -i "s|^PENPOT_SECRET_KEY=.*|PENPOT_SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe(64))')|" .env
sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')|" .env
docker compose up -d
```

Open http://localhost:9001 and register. Passwords need a lowercase letter, an uppercase letter, a digit and a special character.

Email verification is off (`disable-email-verification`) because this stack has no SMTP server. The cookie flag `disable-secure-session-cookies` is only for plain-HTTP testing. Behind HTTPS, set `PENPOT_COOKIE_FLAG=` to empty and `PENPOT_PUBLIC_URI` to your https URL. Also bind the published port to localhost (`"127.0.0.1:${PENPOT_HOST_PORT:-9001}:8080"`), because Docker-published ports bypass host firewalls such as ufw.

## Closing registration

Add `disable-registration` to `PENPOT_FLAGS` in `compose.yaml`, then create users from the CLI:

```bash
docker compose exec penpot-backend python3 manage.py create-profile
```

## Measured (one-off, idle, 2026-11-12)

- All seven containers up and the frontend answered HTTP 200 on the first probe; the backend needed under a minute more (the JVM warming up) before API calls stopped returning 502.
- Registration and `login-with-password` worked through the API (200 with an `auth-token` cookie).
- Idle memory by `docker stats --no-stream`: about 2.6 to 2.8 GiB total, of which the backend was about 1.9 to 2.0 GiB.

## Tear down

```bash
docker compose down -v   # -v deletes the database and uploaded assets
```
