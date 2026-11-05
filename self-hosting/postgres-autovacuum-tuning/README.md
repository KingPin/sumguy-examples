# Postgres Autovacuum Tuning for Small Databases

A Postgres 18 container with a small set of tuned autovacuum globals, monitoring queries, per-table override examples, and a script that reproduces the dead-tuple demo from the article.

Companion to: https://sumguy.com/postgres-autovacuum-tuning/

## What's in here

| File | What it does |
|------|--------------|
| `compose.yaml` | `postgres:18.6`, loads `autovacuum.conf`, listens on `127.0.0.1:55432` |
| `autovacuum.conf` | Minimal config file: the tuned globals, commented |
| `sql/01_dead_tuples.sql` | Dead tuples next to the computed autovacuum trigger point, per table |
| `sql/02_running_vacuums.sql` | Running vacuums via `pg_stat_progress_vacuum` |
| `sql/03_blockers.sql` | Oldest open transactions, idle in transaction, prepared transactions, replication slots |
| `sql/04_wraparound.sql` | `age(datfrozenxid)` per database as a percent of `autovacuum_freeze_max_age` |
| `sql/05_per_table_overrides.sql` | `ALTER TABLE ... SET (...)`, check, and `RESET` |
| `demo.sh` | Builds a 100k-row table, updates 15%, shows the math, then applies an override |

## Prerequisites and tested versions

- Docker Engine 29.9.2 with the Compose plugin
- `postgres:18.6`
- `bash`. `psql` runs inside the container, so you do not need it on the host.

## Run it

```bash
docker compose up -d --wait
./demo.sh                      # takes about 80 seconds (one autovacuum naptime)

# Any of the monitoring files:
docker compose exec -T db psql -U postgres -d app -f /dev/stdin < sql/04_wraparound.sql

docker compose down -v
```

`05_per_table_overrides.sql` expects a table named `hot_sessions`. Create one first:
`docker compose exec -T db psql -U postgres -d app -c "CREATE TABLE hot_sessions (id int)"`.

## Notes

- `autovacuum.conf` is a complete config file for the demo, not an addition to an existing one. On a real server, copy only the lines you want into your own `postgresql.conf` and run `SELECT pg_reload_conf();`. None of these settings need a restart.
- `idle_in_transaction_session_timeout` kills idle sessions. Check how your apps behave before enabling it on a shared server.
- `sql/01_dead_tuples.sql` shows `reltuples` as `-1` for a table that has never been vacuumed or analyzed. Run `ANALYZE` on it first.
