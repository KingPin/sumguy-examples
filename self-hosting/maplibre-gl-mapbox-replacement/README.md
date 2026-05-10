# maplibre-gl-mapbox-replacement

Drop-in replacement for Mapbox GL JS v1 — no token, no license fees, no phone-home. MapLibre GL JS is the community fork that kept the MIT spirit alive after Mapbox went BSL in 2020.

## Prerequisites

- A self-hosted tile server (Tileserver-GL, PMTiles on R2/S3, or OpenFreeMap)
- A browser that supports WebGL (Chrome, Firefox, Safari 15+, Edge)
- No build step — pure CDN HTML

## Run it

Open `index.html` directly in a browser, or serve it with any static file server:

```bash
# Python one-liner
python3 -m http.server 3000

# npx serve
npx serve .

# caddy
caddy file-server --root . --listen :3000
```

Then open http://localhost:3000.

### Point at your tile server

Edit `style.json` — change the tile URL in the `sources.openmaptiles.tiles` array:

```json
"tiles": ["http://your-tileserver:8080/data/v3/{z}/{x}/{y}.pbf"]
```

Edit `index.html` — change `center` to your region and `style` if you rename the file.

### Verify your tile server is alive

```bash
curl "http://localhost:8080/data/v3/11/1097/754.pbf" \
  -o /dev/null -w "%{http_code} %{size_download}b\n"
# 200 + non-zero bytes = working
# 204 = valid empty tile (ocean/forest areas)
# 404 = wrong tile source name or zoom range
```

## Notes

- `style.json` uses the same GL JSON spec as Mapbox. Styles exported from Maputnik work without modification.
- The `["interpolate", ["linear"], ["zoom"], ...]` expression syntax is identical between MapLibre and Mapbox.
- PMTiles alternative: replace the `tiles` URL with a `pmtiles://` URL and add the pmtiles plugin before the MapLibre script tag.
- Mapbox v1 migration is usually a find-and-replace: `mapboxgl.` → `maplibregl.`, swap CDN URLs. Most third-party plugins work unchanged.
- Reduce symbol layers at low zoom levels on mobile — that's the main perf knob for mid-range Android devices.

[Read the article](https://sumguy.com/posts/maplibre-gl-mapbox-replacement/)
