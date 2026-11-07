-- 5M rows, then a parallel hash join big enough to need ~300MB of DSM
CREATE TABLE IF NOT EXISTS big AS
  SELECT g AS id, md5(g::text) AS payload FROM generate_series(1, 5000000) g;
ANALYZE big;
SET work_mem = '64MB';
SELECT count(*) FROM big a JOIN big b USING (id);
