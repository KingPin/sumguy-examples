# Postgres major upgrade with logical replication (17 to 18)

Companion files for [Near-Zero-Downtime Postgres Major Upgrades](https://sumguy.com/postgres-major-upgrade-logical-replication/).

A blue/green upgrade: PostgreSQL 17 (publisher) streams to PostgreSQL 18 (subscriber) while a fake app keeps inserting rows. The script then cuts over, with a reverse subscription (new to old) left in place as a rollback path.

## Files

- `compose.yaml`: `old` (17.11) and `new` (18.6), both with `wal_level=logical`. Ports bind to 127.0.0.1 only (55432, 55433).
- `seed.sql`: `customers` (primary key, `bigserial`) and `events` (no primary key). 500k and 3M rows.
- `load.sh`: write loop. Reads the target host from `.target`; `pause` stops writes.
- `migrate.sh`: the whole run, in order. Schema copy, publication, subscription, initial sync wait, lag check, cutover, sequence sync, row-count check, reverse replication, cleanup.

## Prerequisites and tested versions

- Docker 29.8.2 with the Compose plugin
- Images `postgres:17.11` and `postgres:18.6` (PostgreSQL 19 is not GA at the time of writing)
- No host `psql` needed, everything runs through `docker compose exec`

## Run

```bash
./migrate.sh              # with the rollback subscription
REVERSE=0 ./migrate.sh    # without it
docker compose down -v    # tear down containers and volumes
```

## Notes

- The write pause printed by the script includes `docker compose exec` start-up cost and a fixed 0.5 s wait for in-flight inserts. Treat it as a single run on one machine, not a benchmark.
- Sequences are copied with `setval` because PostgreSQL 17 cannot publish them. Sequence replication needs a publisher on PostgreSQL 19 or later.
- The demo password is `demo`. Do not reuse it.
