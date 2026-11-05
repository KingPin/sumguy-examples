-- Transaction ID age per database. autovacuum_freeze_max_age default is 200000000.
-- A forced anti-wraparound vacuum starts when age passes that value.
SELECT datname,
       age(datfrozenxid) AS xid_age,
       round(100.0 * age(datfrozenxid)
             / current_setting('autovacuum_freeze_max_age')::int, 1) AS pct_of_freeze_max_age
FROM pg_database
ORDER BY xid_age DESC;
