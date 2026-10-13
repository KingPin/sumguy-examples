# Windmill vs Activepieces: self-hosted compose files

Two self-hosted workflow engines, side by side. Companion to https://sumguy.com/windmill-vs-activepieces/

## What is here

- `windmill/`: Windmill compose file based on the official one (Postgres 18, server, 3 workers, native worker, LSP/extra, Caddy), `Caddyfile`, `.env.example`, and two example scripts (`scripts/disk_alert.ts`, `scripts/disk_alert.py`).
- `activepieces/`: Activepieces compose file based on the official one (app, 5 workers, Postgres with pgvector, Redis; image bumped to 0.92.3, telemetry off), `.env.example`, and a custom piece action sketch (`custom-piece/disk-alert-action.ts`).

## Prerequisites and tested versions

- Docker with the Compose plugin.
- Windmill: image `ghcr.io/windmill-labs/windmill:main` (latest release v1.832.0, October 2026). The compose file uses `privileged: true` on the default worker for PID namespace isolation.
- Activepieces: image tag `0.92.3` (latest release, October 2026).
- Compose files were checked with `docker compose config -q` only. Neither stack was booted for this repo.

## Run

```bash
# Windmill: UI on http://localhost (port 80), first login admin@windmill.dev / changeme
cd windmill && cp .env.example .env && docker compose up -d

# Activepieces: UI on http://localhost:8080
cd activepieces && cp .env.example .env
# set AP_API_KEY, AP_ENCRYPTION_KEY (32 hex chars from `openssl rand -hex 16`), AP_JWT_SECRET, AP_POSTGRES_PASSWORD
docker compose up -d
```

Change every default password before exposing either stack. Back up `AP_ENCRYPTION_KEY`: without it, stored connections cannot be decrypted.

## Trigger

```bash
# Windmill async webhook for a script at path u/admin/disk_alert (token from the UI)
curl -X POST "http://localhost/api/w/demo/jobs/run/p/u/admin/disk_alert" \
  -H "Authorization: Bearer $WM_TOKEN" -H "Content-Type: application/json" \
  -d '{"host":"nas01","used_percent":91}'

# Activepieces catch-webhook flow (copy the URL from the trigger step)
curl -X POST "http://localhost:8080/api/v1/webhooks/<FLOW_ID>" -d '{"host":"nas01"}'
```
