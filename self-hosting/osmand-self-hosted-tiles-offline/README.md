# osmand-self-hosted-tiles-offline

Serve raster map tiles from your LAN using Tileserver-GL + MBTiles, then point OsmAnd at your server as a custom tile source. Tiles stay on your network; OsmAnd caches them locally for offline use.

## Prerequisites

- Docker 27.x + Compose v2
- A `.mbtiles` or `.pmtiles` file for your region (see below for sources)
- OsmAnd on Android or iOS (free or Plus tier — custom tile sources work on both)
- Your phone and server on the same LAN (or VPN)

## Run it

### 1. Get tiles

**Option A — download prebuilt MBTiles from OpenMapTiles:**
```bash
# Register free at openmaptiles.org, then download your region
# Example (after login):
wget "https://your-download-url.mbtiles" -O tiles/your-region.mbtiles
```

**Option B — build with tilemaker from a Geofabrik PBF:**
```bash
# Install tilemaker, then:
tilemaker --input your-region.osm.pbf \
          --output tiles/your-region.mbtiles \
          --config config-openmaptiles.json \
          --process process-openmaptiles.lua
```

**Option C — Protomaps PMTiles (no tile server needed for web):**
```bash
wget https://build.protomaps.com/20240101.pmtiles -O tiles/planet.pmtiles
# Update config.json to reference the .pmtiles file
```

### 2. Configure

Edit `tiles/config.json` — change `"mbtiles": "your-region.mbtiles"` to match your actual filename.

Edit `sumguy-tiles.xml` — change the IP address in `url_template` to your server's LAN IP:
```xml
<url_template>http://YOUR_LAN_IP:8080/data/osm-bright/{0}/{1}/{2}.png</url_template>
```

### 3. Start Tileserver-GL

```bash
docker compose up -d
docker compose logs -f tileserver
```

Verify the server is working:
```bash
# Should return a tile image (or 204 for empty tiles)
curl -o /dev/null -w "%{http_code}\n" \
  "http://localhost:8080/data/osm-bright/10/512/341.png"
```

### 4. Import the tile source into OsmAnd

1. Transfer `sumguy-tiles.xml` to your phone (ADB, file manager, cloud storage)
2. In OsmAnd: **Map → Configure Map → Map Source → + (add) → Import from file**
3. Select `sumguy-tiles.xml`
4. The source appears as "SumGuy Tile Server" in the map source list
5. Select it, pan around your region — tiles download and cache locally

## Notes

- OsmAnd's URL template uses `{0}` = zoom, `{1}` = X, `{2}` = Y — NOT `{z}/{x}/{y}`. Get this wrong and tiles won't render or will render in the wrong position.
- `time_to_live: 3600` = tiles expire after 1 hour. Set to `86400` (24h) for static data. Set to `0` for pure offline caching (no re-fetching after first load).
- The `osm-bright` name in `url_template` must match the key in `config.json` under `"data"`.
- Tileserver-GL also serves vector tiles at `/data/osm-bright/{z}/{x}/{y}.pbf` — useful for MapLibre GL web apps on the same server.
- For public-facing setups, put Tileserver-GL behind Caddy or Nginx with rate limiting. The container has no auth.

[Read the article](https://sumguy.com/posts/osmand-self-hosted-tiles-offline/)
