# Self-Host SigNoz: Install Guide

Working files for the SigNoz self-hosted install walkthrough, using **Foundry** (`foundryctl`), which is now the only supported way to install SigNoz. Includes example app instrumentation for Python/Flask and Node.js.

> **Note (2026-08-17):** SigNoz deprecated `install.sh` and the bundled Docker Compose manifests under `deploy/` as of [v0.130.0](https://github.com/SigNoz/signoz/releases/tag/v0.130.0). The hand-rolled `docker-compose.yml` and `otel-collector-config.yaml` that used to live in this folder have been removed because they no longer reflect how SigNoz is built or run. Foundry generates both for you.

## What it does

`casting.yaml` is the entire deployment config. `foundryctl` reads it and generates a full Compose stack into `pours/deployment/`: ClickHouse (telemetrystore), ClickHouse Keeper (telemetrykeeper), PostgreSQL (metastore, holding dashboards/alerts/users), the SigNoz OTel Collector (ingester, listening on 4317/4318), and the SigNoz UI and API server on port 8080.

`app.py` is a Flask demo app with variable latency and a deliberate error route. `tracing.js` is a Node.js OTel bootstrap file. `Caddyfile` is a minimal reverse proxy config for HTTPS.

## Prerequisites

- Docker Engine 20.10+ and Docker Compose v2 (`docker compose`, not `docker-compose`)
- 4 GB RAM allocated to Docker is SigNoz's stated floor. 8 GB is the honest homelab number, 16 GB if you run more than a few services
- 50 to 100 GB disk for a few weeks of retention at moderate volume, SSDs preferred
- Linux or macOS. On Windows use WSL 2 with Docker Engine installed natively inside the distro (ClickHouse Keeper segfaults under Docker Desktop's Windows virtualization layer)
- Ports free: 8080 (UI), 4317 and 4318 (OTLP)

Tested against SigNoz v0.137.1 and foundryctl v0.2.17.

## How to run it

**1. Install foundryctl**

```bash
curl -fsSL https://signoz.io/foundry.sh | bash
foundryctl --help
```

If that comes back "command not found", add `~/.local/bin` to your `PATH`.

**2. Deploy**

```bash
foundryctl cast -f casting.yaml
```

`cast` chains three stages: `gauge` (check prerequisites), `forge` (generate manifests into `pours/deployment/`), then deploy. To read the generated files before anything starts:

```bash
foundryctl gauge -f casting.yaml
foundryctl forge -f casting.yaml
cd pours/deployment && docker compose up -d
```

Give it 60 to 90 seconds on first boot while ClickHouse builds its schema and the migrator runs.

- SigNoz UI: http://your-host:8080 (create the admin account on first visit)
- OTLP gRPC: localhost:4317
- OTLP HTTP: localhost:4318

**Do not hand-edit anything under `pours/`.** The next `forge` overwrites it. Change `casting.yaml` and re-cast.

**Run the Python/Flask demo app:**

```bash
pip install flask opentelemetry-distro opentelemetry-exporter-otlp-proto-grpc
opentelemetry-bootstrap -a install

export OTEL_RESOURCE_ATTRIBUTES="service.name=flask-demo"
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
export OTEL_EXPORTER_OTLP_PROTOCOL="grpc"
opentelemetry-instrument python app.py
```

Then generate some traces:

```bash
curl http://localhost:5000/
curl http://localhost:5000/slow
curl http://localhost:5000/error || true
```

**Run the Node.js demo app:**

```bash
npm install @opentelemetry/sdk-node \
  @opentelemetry/auto-instrumentations-node \
  @opentelemetry/exporter-trace-otlp-grpc \
  @opentelemetry/exporter-metrics-otlp-grpc

node -r ./tracing.js server.js
```

**Optional: HTTPS with Caddy**

Edit `Caddyfile` to replace `signoz.your-domain.com` with your actual domain, then:

```bash
caddy run --config Caddyfile
```

## Upgrading

Bump the image tags in `casting.yaml`, then:

```bash
foundryctl cast -f casting.yaml
docker compose -f pours/deployment/compose.yaml up -d --force-recreate
```

The `--force-recreate` matters: Compose does not restart a container when only the contents of a mounted config file change, so without it you can end up running new configs that nothing has read. Recreate everything in one command rather than restarting services individually, since restarting only the keeper leaves ClickHouse unable to reconnect. Data lives in volumes and is not affected.

## Already running the old Compose stack?

Follow SigNoz's [migration guide](https://github.com/SigNoz/signoz/blob/main/deploy/MIGRATION.md). It reattaches your existing volumes so you keep your data. Keep a copy of your old `docker-compose.yaml` first, since SigNoz no longer distributes it and that copy is your only rollback path, and never pass `-v` when bringing the old stack down.

## Article

https://sumguy.com/self-host-signoz/
