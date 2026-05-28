# HyperDX vs OpenObserve: Side-by-Side Compose Examples

Two ClickHouse-era observability platforms for comparison: HyperDX (all-in-one, ClickHouse-backed, session replay included) and OpenObserve (single-binary, object-storage-friendly, extremely low RAM footprint). Both accept OTLP data.

## What it does

The `hyperdx/` folder runs HyperDX all-in-one — ClickHouse, API, and UI bundled in a single container. The `openobserve/` folder runs OpenObserve in local-disk mode with object storage config commented out for easy switching. `otel_config.py` at the root is a Python FastAPI instrumentation example showing how to point the OTLP exporter at either backend.

## Prerequisites

- Docker 27.x and Docker Compose v2
- HyperDX: 2 GB RAM minimum (ClickHouse runs inside the container; expect 1–2 GB in real use)
- OpenObserve: 256 MB RAM is sufficient in local mode — this thing is genuinely light

## How to run it

**HyperDX:**

```bash
cd hyperdx/
docker compose up -d
# UI at http://localhost:8080 — register on first visit
# OTLP HTTP: http://localhost:4318
# OTLP gRPC: localhost:4317
```

**OpenObserve:**

```bash
cd openobserve/
docker compose up -d
# UI at http://localhost:5080 — login with ZO_ROOT_USER_EMAIL / ZO_ROOT_USER_PASSWORD
# OTLP HTTP: http://localhost:5080/api/default/
# OTLP gRPC: localhost:5081
```

**Run the OTLP instrumentation example:**

```bash
pip install opentelemetry-sdk \
  opentelemetry-exporter-otlp-proto-http \
  opentelemetry-instrumentation-fastapi

# Edit otel_config.py to uncomment the endpoint for your chosen platform
python otel_config.py
```

Note: OpenObserve's OTLP HTTP endpoint requires Basic auth headers. Set `OTEL_EXPORTER_OTLP_HEADERS` with a base64-encoded `email:password` value, or use the commented lines in `otel_config.py`.

## Article

https://sumguy.com/posts/hyperdx-vs-openobserve/
