#!/usr/bin/env bash
# Reproduce the /dev/shm exhaustion error and test both fixes.
set -u
cd "$(dirname "$0")"
docker compose up -d --wait
for svc in pg-default pg-shm pg-mindsm pg-tight; do
  echo "== $svc ($(docker compose exec -T "$svc" df -h --output=size /dev/shm | tail -1 | tr -d ' ') /dev/shm)"
  docker compose exec -T "$svc" psql -U postgres -q -v ON_ERROR_STOP=0 < repro.sql 2>&1 | tail -3
done
echo "== pg-tight OOMKilled: $(docker inspect "$(docker compose ps -q pg-tight)" --format '{{.State.OOMKilled}}')"
echo "Clean up with: docker compose down -v"
