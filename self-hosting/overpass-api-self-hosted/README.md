# overpass-api-self-hosted

Self-host the Overpass API to query OSM tag data without rate limits. Query cafes, libraries, bus stops, anything in OSM — by bounding box, area name, or tag filter.

## Prerequisites

- Docker 27.x + Compose v2
- 4+ GB disk for a state extract (`OVERPASS_SPACE` controls the cap)
- First start downloads the PBF and indexes it — budget 30–90 minutes for a US state

## Run it

### 1. Start the stack

```bash
docker compose up -d
docker compose logs -f overpass
```

The container will download the PBF, import it into Overpass's flat-file DB, then switch to serving mode automatically. Watch logs for `Dispatcher_server started`.

To use a different region, edit `OVERPASS_PLANET_URL` and `OVERPASS_DIFF_URL` in `docker-compose.yml` before first start.

### 2. Test with a simple query

```bash
# Inline POST (avoids shell quoting issues)
curl -s -X POST "http://localhost:12345/api/interpreter" \
  --data-urlencode 'data=[out:json][timeout:25];
node["amenity"="cafe"](40.6,-74.05,40.75,-73.9);
out body;'
```

### 3. Run the example scripts

```bash
chmod +x scripts/query-cafes.sh scripts/query-by-area.sh

# Cafes in lower Manhattan (JSON + CSV)
./scripts/query-cafes.sh

# Libraries in Cook County (via Nominatim area resolution)
AREA="Cook County Illinois" AMENITY=library \
NOMINATIM_HOST=http://localhost:8080 \
./scripts/query-by-area.sh
```

The `query-by-area.sh` script requires a running Nominatim instance to resolve the area name. If you don't have one, use a bounding box in `query-cafes.sh` instead.

## Notes

- `OVERPASS_MODE: init` runs the import once, then the container drops into serving mode. Set to `clone` if you want to replicate from an existing Overpass instance instead of building from PBF.
- `OVERPASS_SPACE: 4000000000` caps disk usage at 4 GB. Increase for larger regions (e.g., `20000000000` for a full US state like California).
- `OVERPASS_META: yes` stores node metadata (timestamps, user info). Set to `no` to save ~30% disk if you don't need it.
- `OVERPASS_DIFF_URL` enables incremental updates from Geofabrik's diff feed. The container applies them automatically.
- Overpass QL's `area()` selector works on OSM relation IDs offset by `+3600000000`. Use Nominatim's `/search` endpoint to resolve human-readable area names to relation IDs.

[Read the article](https://sumguy.com/posts/overpass-api-self-hosted/)
