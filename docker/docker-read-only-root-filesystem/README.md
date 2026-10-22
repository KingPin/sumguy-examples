# Read-only root filesystems in Docker

Companion files for [Read-Only Docker Containers: What Breaks](https://sumguy.com/docker-read-only-root-filesystem/).

## What it does

- `compose.yaml` runs four services with `read_only: true` and the minimum writable paths each one needs: nginx (with an envsubst template), PostgreSQL 18, Redis 8, and a small Python worker.
- `find-writes.sh` runs any image normally for a few seconds, then prints `docker diff` and the directories that received new files. Those directories are your first tmpfs candidates.

## Prerequisites and tested versions

- Docker Engine 29.8.2 with Compose v5
- Images: `nginx:1.30-alpine` (nginx 1.30.6), `postgres:18` (18.6), `redis:8` (8.10.2), `python:3.14-slim` (3.14.9)
- Host port `18080` free

## How to run

```bash
docker compose up -d
docker compose ps          # all four should report healthy
curl localhost:18080       # hello from read-only-nginx
docker compose down -v     # clean up, including volumes
```

Find the writes of another image:

```bash
./find-writes.sh nginx:1.30-alpine -e SOME_VAR=value
WAIT=20 ./find-writes.sh your/image:tag
```

`WAIT` is the number of seconds to let the container run before diffing (default 10).
