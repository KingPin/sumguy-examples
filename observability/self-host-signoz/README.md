# Self-Host SigNoz: Install Guide

Working files for the SigNoz self-hosted install walkthrough. Covers a self-contained Docker Compose setup with ClickHouse, the SigNoz OTel collector, the query service/frontend, and Alertmanager — plus example app instrumentation for Python/Flask and Node.js.

## What it does

`docker-compose.yml` brings up the full SigNoz stack: ClickHouse as the data store, the SigNoz-flavored OTel collector receiving OTLP data on ports 4317/4318, the SigNoz UI on port 3301, and Alertmanager for alert routing. `otel-collector-config.yaml` wires the collector to ClickHouse with separate pipelines for traces, metrics, and logs. `app.py` is a Flask demo app with variable latency and a deliberate error route. `tracing.js` is a Node.js OTel bootstrap file. `Caddyfile` is a minimal reverse proxy config for HTTPS.

## Prerequisites

- Docker 27.x and Docker Compose v2 (`docker compose`, not `docker-compose`)
- 8 GB RAM minimum; 16 GB recommended (ClickHouse alone wants 2–4 GB)
- 50–100 GB disk for a few weeks of retention at moderate volume; SSDs preferred
- Linux (Ubuntu 22.04 / Debian 12 / Rocky 8+ all confirmed working)

## How to run it

```bash
docker compose up -d
# Give it 60-90s for ClickHouse to initialize on first boot
docker compose logs -f --tail=50
```

- SigNoz UI: http://your-host:3301 (create admin account on first visit)
- OTLP gRPC: localhost:4317
- OTLP HTTP: localhost:4318

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

## Article

https://sumguy.com/posts/self-host-signoz/
