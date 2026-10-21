#!/usr/bin/env bash
# End-to-end blue/green major upgrade: PG 17 (old, publisher) -> PG 18 (new, subscriber).
set -euo pipefail
cd "$(dirname "$0")"
REVERSE=${REVERSE:-1}   # 1 = set up reverse replication (new -> old) as a rollback path
o() { docker compose exec -T old psql -U postgres -d app -v ON_ERROR_STOP=1 -At "$@"; }
n() { docker compose exec -T new psql -U postgres -d app -v ON_ERROR_STOP=1 -At "$@"; }
now() { date +%s.%N; }
CONN_OLD="host=old user=postgres password=demo dbname=app"
CONN_NEW="host=new user=postgres password=demo dbname=app"

echo "== 0. start both servers"
docker compose up -d --wait --quiet-pull 2>&1 | grep -v -e Creating -e Created -e Starting -e Started -e Waiting -e Healthy || true
o -c "SHOW wal_level"; o -c "SELECT version()" | cut -c1-30; n -c "SELECT version()" | cut -c1-30

echo "== 1. seed old"
docker compose exec -T old psql -U postgres -d app -q -v ON_ERROR_STOP=1 < seed.sql
o -c "SELECT 'customers', count(*) FROM customers UNION ALL SELECT 'events', count(*) FROM events"

echo "== 2. roles and schema (DDL is not replicated)"
docker compose exec -T old pg_dumpall -U postgres --globals-only | docker compose exec -T new psql -U postgres -q >/dev/null 2>&1 || true  # the postgres role already exists
docker compose exec -T old pg_dump -U postgres -d app --schema-only | docker compose exec -T new psql -U postgres -d app -q -v ON_ERROR_STOP=1 -o /dev/null

echo "== 3. publication on old (events has no PK: UPDATE/DELETE need a replica identity)"
o -c "CREATE PUBLICATION upgrade_pub FOR ALL TABLES"
echo "-- before REPLICA IDENTITY FULL:"
o -c "UPDATE events SET kind = kind WHERE customer_id = 1" 2>&1 || true
o -c "ALTER TABLE events REPLICA IDENTITY FULL"
o -c "UPDATE events SET kind = kind WHERE customer_id = 1" 

echo "== 4. start write load against old"
rm -f .stop load.errors load.count; echo old > .target
./load.sh &
LOAD_PID=$!
sleep 3

echo "== 5. subscribe from new, wait for initial table copy"
t0=$(now)
n -c "CREATE SUBSCRIPTION upgrade_sub CONNECTION '$CONN_OLD' PUBLICATION upgrade_pub"
until [ "$(n -c "SELECT count(*) FROM pg_subscription_rel WHERE srsubstate <> 'r'")" = 0 ]; do sleep 0.5; done
t1=$(now)
printf 'initial sync: %.1f s\n' "$(awk "BEGIN{print $t1 - $t0}")"
n -c "SELECT srrelid::regclass, srsubstate FROM pg_subscription_rel"

echo "== 6. steady state: lag in bytes while the load runs"
o -c "SELECT slot_name, active, pg_current_wal_lsn() - confirmed_flush_lsn AS lag_bytes FROM pg_replication_slots"
sleep 5

echo "== 7. CUTOVER"
echo pause > .target
tp=$(now)
sleep 0.5                                   # let in-flight inserts finish
LSN=$(o -c "SELECT pg_current_wal_lsn()")
until [ "$(o -c "SELECT confirmed_flush_lsn >= '$LSN' FROM pg_replication_slots WHERE slot_name = 'upgrade_sub'")" = t ]; do sleep 0.1; done
echo "lag zero at $LSN"
# sequences: PG 17 as publisher cannot replicate them, so copy the values by hand
o -c "SELECT format('SELECT setval(%L, %s, true)', schemaname || '.' || sequencename, last_value) FROM pg_sequences WHERE last_value IS NOT NULL" | n -q >/dev/null
echo "-- sequence on new vs old:"
n -c "SELECT last_value FROM customers_id_seq"; o -c "SELECT last_value FROM customers_id_seq"
echo "-- row counts (old | new):"
for t in customers events; do echo "$t $(o -c "SELECT count(*) FROM $t") | $(n -c "SELECT count(*) FROM $t")"; done
if [ "$REVERSE" = 1 ]; then
  printf 'drained after %.2f s\n' "$(awk "BEGIN{print $(now) - $tp}")"
  n -c "CREATE PUBLICATION rollback_pub FOR ALL TABLES"
  o -c "CREATE SUBSCRIPTION rollback_sub CONNECTION '$CONN_NEW' PUBLICATION rollback_pub WITH (copy_data = false)"
fi
printf 'reverse replication ready after %.2f s\n' "$(awk "BEGIN{print $(now) - $tp}")"
n -c "ALTER TABLE events REPLICA IDENTITY FULL"
n -c "DROP SUBSCRIPTION upgrade_sub"
echo new > .target
tr=$(now)
printf 'write pause: %.2f s\n' "$(awk "BEGIN{print $tr - $tp}")"

echo "== 8. writes now land on new; let the load run, then stop it"
sleep 5
touch .stop; wait $LOAD_PID
echo "load inserts: $(cat load.count); write errors: $( [ -f load.errors ] && wc -l < load.errors || echo 0)"
o -c "DROP PUBLICATION upgrade_pub" || true

if [ "$REVERSE" = 1 ]; then
  sleep 2
  echo "-- rollback path check, row counts (old | new):"
  for t in customers events; do echo "$t $(o -c "SELECT count(*) FROM $t") | $(n -c "SELECT count(*) FROM $t")"; done
fi
echo "== final: new is PG $(n -c "SHOW server_version")"
