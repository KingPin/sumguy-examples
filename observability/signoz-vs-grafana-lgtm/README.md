# SigNoz vs Grafana LGTM Stack: Side-by-Side Compose Examples

Two complete observability stacks for home lab evaluation: the Grafana LGTM stack (Loki + Grafana + Tempo + Mimir) assembled from individual components, and SigNoz as a unified alternative. Both accept OpenTelemetry data via OTLP.

## What it does

The `lgtm/` folder has a minimal Grafana LGTM Compose file requiring five containers and six config files before a single trace is sent. The `signoz/` folder has the SigNoz equivalent — four containers and one collector config. `instrumentation.py` at the root is a shared example showing how OTLP wiring works with either backend.

## Prerequisites

- Docker 27.x and Docker Compose v2 (`docker compose`, not `docker-compose`)
- 8 GB RAM minimum (ClickHouse-based SigNoz stack); the LGTM stack is lighter but Mimir adds overhead
- Note: the LGTM `docker-compose.yml` is a skeleton — you must supply `prometheus.yml`, `mimir.yaml`, `loki.yaml`, `tempo.yaml`, and Grafana provisioning YAML files before it will start cleanly

## How to run it

**SigNoz stack:**

```bash
cd signoz/
docker compose up -d
# UI at http://localhost:3301
# OTLP gRPC: localhost:4317
# OTLP HTTP: localhost:4318
```

**LGTM stack** (after adding the required config files):

```bash
cd lgtm/
docker compose up -d
# Grafana UI at http://localhost:3000 (admin / changeme)
```

**Run the instrumentation example** (against SigNoz):

```bash
pip install opentelemetry-sdk opentelemetry-exporter-otlp
python instrumentation.py
```

## Article

https://sumguy.com/posts/signoz-vs-grafana-lgtm/
