-- Dead tuples vs. the point where autovacuum fires, per table.
-- Formula (PG 18): LEAST(max_threshold, base_threshold + scale_factor * reltuples)
-- Per-table reloptions override the globals; COALESCE falls back to the server setting.
WITH cfg AS (
  SELECT
    current_setting('autovacuum_vacuum_threshold')::float8      AS base,
    current_setting('autovacuum_vacuum_scale_factor')::float8   AS scale,
    current_setting('autovacuum_vacuum_max_threshold')::float8  AS maxthr
), t AS (
  SELECT c.oid, c.relname, c.reltuples,
    (SELECT split_part(o, '=', 2)::float8 FROM unnest(c.reloptions) o
      WHERE o LIKE 'autovacuum_vacuum_threshold=%')      AS o_base,
    (SELECT split_part(o, '=', 2)::float8 FROM unnest(c.reloptions) o
      WHERE o LIKE 'autovacuum_vacuum_scale_factor=%')   AS o_scale
  FROM pg_class c
  WHERE c.relkind = 'r' AND c.relnamespace = 'public'::regnamespace
)
SELECT s.relname,
       t.reltuples::bigint AS reltuples,
       s.n_live_tup,
       s.n_dead_tup,
       round(LEAST(cfg.maxthr, COALESCE(t.o_base, cfg.base)
             + COALESCE(t.o_scale, cfg.scale) * t.reltuples)) AS trigger_at,
       s.n_dead_tup > LEAST(cfg.maxthr, COALESCE(t.o_base, cfg.base)
             + COALESCE(t.o_scale, cfg.scale) * t.reltuples)  AS due,
       s.last_autovacuum,
       s.autovacuum_count
FROM pg_stat_user_tables s
JOIN t ON t.oid = s.relid
CROSS JOIN cfg
ORDER BY s.n_dead_tup DESC;
