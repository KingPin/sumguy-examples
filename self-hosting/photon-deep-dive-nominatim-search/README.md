# photon-deep-dive-nominatim-search

Run Photon (fuzzy/autocomplete search) and Nominatim (structured + reverse geocoding) side by side, unified behind a Caddy reverse proxy. Photon handles the "as-you-type" search box; Nominatim handles address lookup and reverse geocoding.

## Prerequisites

- Docker 27.x + Compose v2
- ~12 GB disk for a regional Nominatim import; ~90 GB extra for Photon planet dump (or less if building from your own Nominatim DB)
- Caddy (optional) if you want the unified proxy

## Run it

### 1. Start Nominatim (do this first — Photon can import from it)

```bash
cp .env.example .env   # edit NOMINATIM_PASSWORD
docker compose up -d nominatim
docker compose logs -f nominatim
# Wait for import to complete (hours for large extracts)
```

### 2. Populate Photon data

**Option A — planet dump (fastest):**
```bash
# Download latest prebuilt Elasticsearch dump (~90 GB)
wget https://download1.graphhopper.com/public/photon-db-latest.tar.bz2
tar -xjf photon-db-latest.tar.bz2 -C /path/to/photon-data/
```

**Option B — build from your Nominatim DB (right-sized):**
```bash
# Run from inside the Nominatim container after import is done
docker exec nominatim java -jar /photon/photon-*.jar \
  -nominatim-import \
  -host localhost \
  -port 5432 \
  -database nominatim \
  -user nominatim \
  -password yourpassword \
  -languages en,fr,de
```

### 3. Start Photon

```bash
docker compose up -d photon
```

### 4. Test both APIs

```bash
# Photon — fuzzy search, returns GeoJSON FeatureCollection
curl "http://localhost:2322/api?q=1600+Pensilvania+Ave&limit=5&lang=en"

# Photon — bias toward a location
curl "http://localhost:2322/api?q=pizza&lat=38.8977&lon=-77.0365&limit=5"

# Nominatim — structured search
curl "http://localhost:8080/search?q=1600+Pennsylvania+Ave&format=json&addressdetails=1&limit=5"

# Nominatim — reverse geocoding
curl "http://localhost:8080/reverse?lat=38.8977&lon=-77.0365&format=json"
```

### 5. (Optional) Caddy proxy

Install Caddy on the host, copy the `Caddyfile` to `/etc/caddy/Caddyfile`, then:
```bash
systemctl reload caddy
```

Frontend calls `/photon/api?q=...` for autocomplete and `/nominatim/reverse?lat=...&lon=...` for everything else.

## Notes

- Photon does not support reverse geocoding well — use Nominatim's `/reverse` endpoint for that.
- The `lang` parameter on Photon returns localised place names if OSM has them (`?lang=de` for German).
- Photon's planet dump is always the full planet — no regional subset available from Komoot. If you only need one region, build from your Nominatim DB (Option B) instead.

[Read the article](https://sumguy.com/posts/photon-deep-dive-nominatim-search/)
