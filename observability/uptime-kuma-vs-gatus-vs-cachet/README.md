# Uptime Kuma vs Gatus vs Cachet

Companion files for the post [Uptime Kuma vs Gatus vs Cachet](https://sumguy.com/uptime-kuma-vs-gatus-vs-cachet/).

Three self-hosted status page options, each in its own folder:

| Folder | What it is |
|---|---|
| `uptime-kuma/` | GUI-driven monitor with status pages (Compose only) |
| `gatus/` | YAML health checks, built-in dashboard, Cachet bridge via custom alert, external-endpoint push script |
| `cachet/` | Cachet 3.x built from source (no official image), plus a script that sets component status through the API |

## Prerequisites and tested versions

Tested 2026-10-14 with Docker 29.8 and Docker Compose.

- Uptime Kuma 2.5.6 (`louislam/uptime-kuma:2`)
- Gatus v5.37.0 (`ghcr.io/twin/gatus:v5.37.0`)
- Cachet `3.x` branch (reports `3.x-dev`, PHP 8.3). Cachet has no tagged 3.x release and no maintained official Docker image, so the build clones a moving branch. Treat it as pre-release. The last tagged release is v2.4.1 (2023-11-07).

## Run

Uptime Kuma:

```bash
cd uptime-kuma && docker compose up -d   # http://localhost:3001
```

Cachet:

```bash
cd cachet
cp .env.example .env                      # set APP_KEY: echo "base64:$(openssl rand -base64 32)"
docker compose up -d --build              # http://localhost:8000
docker compose exec cachet php artisan cachet:make:user admin@example.com \
  --password='pick-a-real-one' --admin=1 --name=admin
docker compose exec cachet php artisan tinker \
  --execute='echo App\Models\User::first()->createToken("gatus")->plainTextToken;'
```

Create a component named Blog (id 1) in the dashboard, or with `POST /api/components`. Cachet writes need a bearer token.

Gatus (joined to the Cachet Compose network so `cachet:8000` resolves):

```bash
cd gatus
export CACHET_TOKEN=<token from above> PUSH_TOKEN=<random string>
docker compose up -d                      # http://localhost:8080
```

`config.yaml` points at `https://example.com/`. Change it to your own service. If Gatus runs in a separate Compose project, attach it to the Cachet network or change the alert URL.

Push a job result to Gatus: `PUSH_TOKEN=... ./push-backup-status.sh true`.

Set a Cachet status by hand: `CACHET_TOKEN=... ./set-component-status.sh 1 4`.

Cachet component status values: 1 operational, 2 performance issues, 3 partial outage, 4 major outage, 5 unknown, 6 under maintenance.

## Notes

- Gatus defaults to in-memory storage. This config uses SQLite on a volume so history survives restarts.
- The Cachet container runs `php artisan serve`, a development server. Keep it on your LAN or behind a reverse proxy.
