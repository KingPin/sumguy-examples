-- Sessions that hold back vacuum: oldest open transactions first.
SELECT pid, usename, state,
       now() - xact_start AS xact_age,
       backend_xmin,
       left(query, 60) AS last_query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
  AND pid <> pg_backend_pid()
ORDER BY xact_start
LIMIT 10;

-- Idle in transaction only.
SELECT pid, usename, now() - state_change AS idle_for
FROM pg_stat_activity
WHERE state = 'idle in transaction'
ORDER BY state_change;

-- Also check for forgotten prepared transactions and replication slots.
SELECT gid, prepared FROM pg_prepared_xacts;
SELECT slot_name, active, xmin, catalog_xmin FROM pg_replication_slots;
