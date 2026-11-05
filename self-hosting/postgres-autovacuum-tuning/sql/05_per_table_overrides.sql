-- Per-table overrides for a hot table. These live in pg_class.reloptions.
ALTER TABLE hot_sessions SET (
  autovacuum_vacuum_scale_factor = 0.01,   -- 1% of the table instead of 20%
  autovacuum_vacuum_threshold    = 1000,   -- base added to the percentage
  autovacuum_vacuum_cost_limit   = 2000    -- this table may work faster than the global budget
);

-- Insert-only tables (event logs): trigger on inserts so rows get frozen and
-- the visibility map stays fresh.
ALTER TABLE hot_sessions SET (
  autovacuum_vacuum_insert_scale_factor = 0.05,
  autovacuum_vacuum_insert_threshold    = 5000
);

-- Check what is set.
SELECT relname, reloptions
FROM pg_class
WHERE relname = 'hot_sessions';

-- Undo.
ALTER TABLE hot_sessions RESET (
  autovacuum_vacuum_scale_factor,
  autovacuum_vacuum_threshold,
  autovacuum_vacuum_cost_limit,
  autovacuum_vacuum_insert_scale_factor,
  autovacuum_vacuum_insert_threshold
);
