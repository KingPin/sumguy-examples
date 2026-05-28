# SigNoz vs Jaeger: Side-by-Side Compose Examples

Two distributed tracing backends for comparison: Jaeger with Elasticsearch storage and SigNoz with ClickHouse. Both accept OTLP traces on the same ports — the instrumentation code doesn't change between them.

## What it does

The `jaeger/` folder runs Jaeger all-in-one backed by Elasticsearch. The `signoz/` folder runs the SigNoz stack (ClickHouse + OTel collector + query service + frontend). `instrumentation.py` at the root demonstrates how a single OTLP exporter works against either backend — swap the endpoint comment and you're done.

## Prerequisites

- Docker 27.x and Docker Compose v2
- Jaeger stack: 2 GB RAM minimum (Elasticsearch is the heavy piece, not Jaeger itself)
- SigNoz stack: 8 GB RAM minimum (ClickHouse wants 2–4 GB on its own)

## How to run it

**Jaeger (Elasticsearch-backed):**

```bash
cd jaeger/
docker compose up -d
# UI at http://localhost:16686
# OTLP gRPC: localhost:4317
# OTLP HTTP: localhost:4318
```

**Quick single-node Jaeger** (no Elasticsearch, in-memory, dev only):

```bash
docker run -d --name jaeger \
  -p 16686:16686 \
  -p 4317:4317 \
  -p 4318:4318 \
  jaegertracing/all-in-one:latest
```

**SigNoz:**

```bash
cd signoz/
docker compose up -d
# UI at http://localhost:3301
# OTLP gRPC: localhost:4317
# OTLP HTTP: localhost:4318
```

**Send a test trace** (against whichever backend is running on 4317):

```bash
pip install opentelemetry-sdk opentelemetry-exporter-otlp-proto-grpc
python instrumentation.py
```

## Article

https://sumguy.com/posts/signoz-vs-jaeger/
