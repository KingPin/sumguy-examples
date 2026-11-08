# Langfuse vs Phoenix: self-hosted LLM tracing

Two Docker Compose stacks and one script that sends the same OpenAI-compatible chat call to each backend. Companion to [Langfuse vs Phoenix: Self-Host LLM Tracing](https://sumguy.com/langfuse-vs-phoenix/).

## What is here

| Path | What it does |
| --- | --- |
| `langfuse/docker-compose.yml` | Langfuse v4: web, worker, Postgres, ClickHouse, Redis, MinIO (6 containers) |
| `phoenix/docker-compose.yml` | Arize Phoenix with Postgres (2 containers) |
| `trace_demo.py` | One chat completion, traced into either backend |

## Prerequisites and tested versions

Tested 2026-11-08 on Docker 29 with Docker Compose and `uv`.

| Image | Tag |
| --- | --- |
| Langfuse web | `docker.langfuse.com/langfuse/langfuse:4.76.0` |
| Langfuse worker | `docker.langfuse.com/langfuse/langfuse-worker:4.76.0` |
| ClickHouse | `clickhouse/clickhouse-server:26.3.62.3` |
| Postgres | `postgres:17` |
| Redis | `redis:7` |
| MinIO | `cgr.dev/chainguard/minio` (floating `latest`, as in the official file) |
| Phoenix | `arizephoenix/phoenix:version-21.0.0` |

Python packages: `langfuse==5.2.0`, `arize-phoenix-otel==0.17.3`, `openinference-instrumentation-openai==0.1.69`, `openai`.

You need an OpenAI-compatible endpoint. Any of these work:

```bash
# Ollama
export OPENAI_BASE_URL=http://localhost:11434/v1 MODEL=your-model-tag
# llama.cpp server
export OPENAI_BASE_URL=http://localhost:8080/v1 MODEL=your-model-name
```

## Run Langfuse

```bash
cd langfuse
cp .env.example .env        # replace every CHANGEME (openssl rand -hex 32)
docker compose up -d
# UI: http://localhost:3200  login: admin@example.com + LANGFUSE_INIT_USER_PASSWORD

set -a; . ./.env; set +a
export LANGFUSE_PUBLIC_KEY=$LANGFUSE_INIT_PROJECT_PUBLIC_KEY
export LANGFUSE_SECRET_KEY=$LANGFUSE_INIT_PROJECT_SECRET_KEY
export LANGFUSE_HOST=http://localhost:3200
cd ..
uv run --with langfuse==5.2.0 --with openai trace_demo.py langfuse
```

Check that the trace arrived. In v4 the old `/api/public/traces` endpoint returns 404 on a fresh install, so query the v2 observations API:

```bash
curl -s -u "$LANGFUSE_PUBLIC_KEY:$LANGFUSE_SECRET_KEY" \
  "http://localhost:3200/api/public/v2/observations?limit=5&fields=core,basic,io,usage"
```

## Run Phoenix

```bash
cd phoenix
cp .env.example .env        # replace every CHANGEME (openssl rand -hex 24)
docker compose up -d
# UI: http://localhost:6106  (OTLP/HTTP on 6106, OTLP/gRPC on 4417)

set -a; . ./.env; set +a
export PHOENIX_COLLECTOR_ENDPOINT=http://localhost:6106
export PHOENIX_API_KEY=$PHOENIX_ADMIN_SECRET
cd ..
uv run --with arize-phoenix-otel==0.17.3 \
  --with openinference-instrumentation-openai==0.1.69 \
  --with openai trace_demo.py phoenix
```

Check that the span arrived:

```bash
curl -s -H "Authorization: Bearer $PHOENIX_ADMIN_SECRET" \
  "http://localhost:6106/v1/projects/demo/spans?limit=5"
```

Phoenix reads `PHOENIX_DEFAULT_ADMIN_INITIAL_PASSWORD` to set the first admin password. The kit does not set it, and the UI login was not exercised during testing: the checks above use the bearer token.

## Clean up

```bash
docker compose down -v      # run in each stack directory
```

Run one stack at a time. Both bind to `127.0.0.1` only.

## Gotchas found while testing

- Phoenix v21 turns authentication on whenever the server binds a non-loopback address. Inside Docker that is always. Unauthenticated trace posts get a 401.
- `register()` from `arize-phoenix-otel` defaults to gRPC on port 4317 when the endpoint is not a full `/v1/traces` URL. A remapped host port is ignored. The script passes the full URL.
- Langfuse v4 runs in events-only mode: no `/api/public/traces` on a new deployment.

Source: https://sumguy.com/langfuse-vs-phoenix/
