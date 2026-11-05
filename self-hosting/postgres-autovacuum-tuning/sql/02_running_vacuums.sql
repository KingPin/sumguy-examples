-- Vacuums running right now (manual and autovacuum).
SELECT p.pid,
       p.relid::regclass AS table_name,
       p.phase,
       p.heap_blks_total,
       p.heap_blks_scanned,
       p.heap_blks_vacuumed,
       p.num_dead_item_ids,
       a.query
FROM pg_stat_progress_vacuum p
JOIN pg_stat_activity a USING (pid);
