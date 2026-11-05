#!/usr/bin/env bash
# Reproduces the dead-tuple demo. Run after `docker compose up -d --wait`.
# Autovacuum is switched off on the demo tables at first so the numbers stay
# put while we look at them, then switched on with a per-table override.
set -euo pipefail
cd "$(dirname "$0")"
psql() { docker compose exec -T db psql -U postgres -d app -v ON_ERROR_STOP=1 "$@"; }

psql -q <<'SQL'
DROP TABLE IF EXISTS big_hot, small_cfg;
CREATE TABLE big_hot   (id int PRIMARY KEY, payload text) WITH (autovacuum_enabled = off);
CREATE TABLE small_cfg (id int PRIMARY KEY, v text)       WITH (autovacuum_enabled = off);
INSERT INTO big_hot   SELECT g, md5(g::text) FROM generate_series(1,100000) g;
INSERT INTO small_cfg SELECT g, 'x' FROM generate_series(1,100) g;
SELECT pg_sleep(2);
ANALYZE big_hot, small_cfg;
-- Update 15% of the big table and 15 rows of the small one.
UPDATE big_hot   SET payload = 'changed' WHERE id <= 15000;
UPDATE small_cfg SET v = 'y' WHERE id <= 15;
SQL
sleep 2   # stats flush
echo "== threshold math (defaults: 50 + 0.2 * reltuples) =="
psql -f /dev/stdin < sql/01_dead_tuples.sql

echo "== now enable autovacuum on big_hot with a per-table override =="
psql <<'SQL'
ALTER TABLE big_hot SET (autovacuum_enabled = on, autovacuum_vacuum_scale_factor = 0.01, autovacuum_vacuum_threshold = 1000);
SQL
echo "waiting for the 1 min autovacuum naptime..."
sleep 75
psql -f /dev/stdin < sql/01_dead_tuples.sql
psql -c "DROP TABLE big_hot, small_cfg;"
