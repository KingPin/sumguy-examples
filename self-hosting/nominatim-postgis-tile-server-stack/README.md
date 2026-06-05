# Full Self-Hosted Maps Stack: Nominatim + PostGIS + Martin

End-to-end self-hosted maps: address geocoding via [Nominatim](https://nominatim.org/), spatial queries via [PostGIS](https://postgis.net/), and vector tile serving via [Martin](https://github.com/maplibre/martin). All behind a single [Caddy](https://caddyserver.com/) reverse proxy.

Companion to the article: [Full Self-Hosted Maps Stack](https://sumguy.com/posts/nominatim-postgis-tile-server-stack/) on SumGuy's Ramblings.

## What it does

- Runs PostgreSQL + PostGIS as a shared database (with an `osm` schema for tile-serving data)
- Runs Nominatim as a separate service for address geocoding
- Runs Martin to serve PostGIS tables as vector tiles
- Puts Caddy in front so each service has its own hostname (`geocode.lan`, `tiles.lan`)

## Prerequisites

- Docker and Docker Compose
- A box with at least 32 GB RAM and 1 TB NVMe (continental scale)
- Tested versions: `postgis/postgis:16-3.4`, `mediagis/nominatim:4.5`, `ghcr.io/maplibre/martin:latest`, `caddy:2`
- A separate `osm2pgsql` step (not in this Compose file) to populate the `osm` schema with tile-friendly tables

## How to run it

### 1. Set passwords

```bash
cp .env.example .env
# edit .env — set both POSTGRES_PASSWORD and NOMINATIM_PASSWORD
```

### 2. Start the stack

```bash
docker compose up -d
docker compose logs -f
```

The Nominatim import will take 6–18 hours for North America. Postgres and Martin start immediately.

### 3. Create the osm schema for tiles

```bash
docker exec -it postgres psql -U postgres -d maps -c "CREATE SCHEMA osm;"
```

### 4. Import OSM data into the osm schema for tile serving

This is the part that varies a lot depending on which style and which extract you use. The `style.lua` included in this folder is a minimal osm2pgsql flex style that produces exactly the `osm.roads`, `osm.water`, and `osm.buildings` tables that `martin-config.yaml` auto-publishes (geometries in EPSG:3857). Copy it into `./data/` so it lands at `/data/style.lua` in the container:

```bash
mkdir -p data
cp style.lua data/style.lua
# download a PBF extract into data/ too, e.g. north-america-latest.osm.pbf

docker run --rm \
  -v $(pwd)/data:/data \
  -e PGPASSWORD=$POSTGRES_PASSWORD \
  --network=host \
  iboates/osm2pgsql:latest \
  osm2pgsql \
    --create \
    --output=flex \
    --style=/data/style.lua \
    --slim \
    --cache=8000 \
    --number-processes=8 \
    -H localhost -d maps -U postgres \
    /data/north-america-latest.osm.pbf
```

The bundled `style.lua` is intentionally minimal (roads, water, buildings). For a richer schema, start from osm2pgsql's own flex examples — [`generic.lua`](https://github.com/osm2pgsql-dev/osm2pgsql/tree/master/flex-config) is a solid base — and add layers as needed. Note that OpenMapTiles itself imports via imposm3 + YAML mappings, not an osm2pgsql Lua style, so there's no drop-in `style.lua` from that project.

### 5. Smoke test

```bash
# Geocoding
curl "http://localhost:8080/search?q=1600+Pennsylvania+Ave+Washington&format=json"

# Tiles catalog
curl "http://localhost:3000/catalog"

# Spatial query against PostGIS
docker exec -it postgres psql -U postgres -d maps -c "SELECT count(*) FROM osm.roads;"
```

### 6. Front-end usage

Point a MapLibre or Leaflet client at `http://tiles.lan/{table_name}/{z}/{x}/{y}` for tiles, and `http://geocode.lan/search?q=...` for geocoding. See the article for a minimal MapLibre HTML example.

## Files

- `docker-compose.yml` — full stack (Postgres, Nominatim, Martin, Caddy)
- `.env.example` — passwords; copy to `.env`
- `martin-config.yaml` — Martin config for auto-publishing the `osm` schema
- `style.lua` — minimal osm2pgsql flex style; produces `osm.roads`, `osm.water`, `osm.buildings`
- `Caddyfile` — reverse proxy with two hostnames

## Notes

- Nominatim's `mediagis` image runs its own internal Postgres for Nominatim data. The shared `postgis/postgis` instance is for the tile schema and your spatial queries. If you need Nominatim and tile data in the same Postgres instance, you'll need to use the upstream `nominatim/nominatim` image with custom configuration — not covered by this example.
- `shm_size: 1gb` on Postgres and Nominatim is not optional.
- CORS on the tile server is open by default (`Access-Control-Allow-Origin: *`). Restrict it in production.
- The Nominatim import alone takes 6–18 hours. The osm2pgsql import for tiles takes another 4–6 hours.

## Reading

- [Martin docs](https://maplibre.org/martin/)
- [Nominatim docs](https://nominatim.org/release-docs/latest/)
- [PostGIS docs](https://postgis.net/documentation/)
- [SumGuy's Ramblings — Nominatim install](https://sumguy.com/posts/nominatim-self-hosted-geocoding-server/)
- [SumGuy's Ramblings — PostGIS for self-hosted mapping](https://sumguy.com/posts/postgis-self-hosted-mapping/)
