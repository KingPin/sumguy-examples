# Temporal home lab workflows

A fake nightly backup as a Temporal workflow: snapshot, compress, upload, verify, notify. The upload step fails twice on purpose so you can watch retries. A durable timer sits between upload and verify so you can kill the worker mid-run and watch the workflow resume.

Companion to: https://sumguy.com/temporal-vs-cron-durable-home-lab-jobs/

Activities only write to `/tmp/temporal-homelab`. No credentials, no network.

## Prerequisites

Tested with:

- Docker 29.8 with Compose
- uv 0.11
- Python 3.10 or newer (SDK requirement)
- `temporalio` 1.33.0 (pinned in `pyproject.toml`)
- Temporal server 1.32.0, admin-tools 1.32.0, UI 2.54.1 (pinned in `docker-compose.yml`)

## Run it

1. Start the stack (Postgres, schema setup, server, namespace, UI):

   ```bash
   docker compose up -d
   ```

2. Start the worker in one terminal:

   ```bash
   uv run python worker.py
   ```

3. Start a workflow from another terminal:

   ```bash
   uv run python starter.py photos
   ```

4. Open the UI at http://localhost:8080 and click the workflow.
5. Try the crash test: run step 3 again, and press Ctrl+C in the worker terminal while the workflow is running. Start the worker again. The workflow finishes where it stopped.
6. Tear down: `docker compose down -v`

## Lighter option: no Docker Compose

The Temporal CLI ships a dev server with SQLite and a UI on port 8233:

```bash
temporal server start-dev --db-filename ./temporal.db
```

Run `worker.py` and `starter.py` unchanged. Without `--db-filename`, history lives in memory and dies with the process.

## Schedule it (replaces the crontab line)

```bash
temporal schedule create \
  --schedule-id nightly-photos \
  --cron "0 2 * * *" \
  --workflow-id nightly-backup-photos \
  --type NightlyBackup \
  --task-queue homelab \
  --input '{"target":"photos","settle_seconds":10}'
```

## Files

- `docker-compose.yml`: Postgres 16 + Temporal server + UI, ports bound to localhost
- `dynamicconfig/development-sql.yaml`: minimal dynamic config the server image expects
- `activities.py`, `workflows.py`, `worker.py`, `starter.py`: the Python side
