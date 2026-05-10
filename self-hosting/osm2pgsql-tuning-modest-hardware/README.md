# osm2pgsql-tuning-modest-hardware

Squeeze a fast OSM import out of a mid-range box (16 GB RAM, 8 cores, NVMe) using flex mode, a minimal Lua style, and Postgres bulk-import settings.

## Prerequisites

- osm2pgsql 1.7+ (flex mode stable)
- PostgreSQL 14+ with PostGIS
- Tested on Docker 27.x; also works bare-metal
- A regional `.osm.pbf` extract from [Geofabrik](https://download.geofabrik.de)

## Run it

### 1. Apply Postgres import tuning

```bash
# Copy the tuned config (adjust path to your Postgres data dir)
cp postgresql.conf /etc/postgresql/16/main/postgresql.conf

# Reload most settings without restart
psql -U postgres -c "SELECT pg_reload_conf();"
# wal_level change requires a full restart:
# systemctl restart postgresql
```

### 2. Download a regional extract

```bash
mkdir -p /opt/osrm/data
wget https://download.geofabrik.de/north-america/us/texas-latest.osm.pbf \
     -O /opt/osrm/data/texas-latest.osm.pbf
```

### 3. Run the import (16 GB / 8-core box)

```bash
osm2pgsql \
  --output=flex \
  --style=roads.lua \
  --slim \
  --drop \
  --cache=4000 \
  --number-processes=4 \
  --host=localhost \
  --database=osm \
  --username=osm \
  texas-latest.osm.pbf
```

Adjust `--cache` and `--number-processes` to your hardware:
- 8 GB RAM → `--cache 2000`, 2–3 processes
- 32 GB RAM → `--cache 8000`, 6 processes

### 4. Revert Postgres settings after import

```bash
psql -U postgres -c "ALTER SYSTEM RESET fsync;"
psql -U postgres -c "ALTER SYSTEM RESET synchronous_commit;"
psql -U postgres -c "ALTER SYSTEM RESET full_page_writes;"
psql -U postgres -c "SELECT pg_reload_conf();"

# Run ANALYZE so the planner has fresh stats
psql -U osm -d osm -c "ANALYZE;"
```

### 5. Monitor index creation

Index builds are the long part (20–60 min per spatial index). Watch progress:

```bash
watch -n5 "psql -U osm -d osm -c \
  \"SELECT phase, blocks_done, blocks_total, \
    round(blocks_done::numeric/nullif(blocks_total,0)*100, 1) AS pct \
    FROM pg_stat_progress_create_index;\""
```

## Notes

- `--slim --drop` uses disk-backed node storage during import then deletes the slim tables after — saves disk, slightly slower. Good for one-shot imports.
- `fsync=off` risks data loss on crash during import. Acceptable because you can re-import from the PBF. **Never leave it in production.**
- `--number-processes` parallelises geometry processing, not index creation. Adding more processes past `cores/2` rarely helps — you hit IO contention first.
- The `roads.lua` style imports only highway ways. Adapt it to your schema needs.

[Read the article](https://sumguy.com/posts/osm2pgsql-tuning-modest-hardware/)
