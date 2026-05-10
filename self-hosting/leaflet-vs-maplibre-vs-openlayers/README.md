# leaflet-vs-maplibre-vs-openlayers

Three HTML files, same map, three different libraries. Open them side by side to feel the difference in API verbosity, bundle size, and renderer behavior.

## Prerequisites

- A browser with WebGL support (for `maplibre.html`)
- No build step — pure CDN HTML

## Run it

Open any file directly in a browser, or serve the directory:

```bash
python3 -m http.server 3000
# Then open:
# http://localhost:3000/leaflet.html
# http://localhost:3000/maplibre.html
# http://localhost:3000/openlayers.html
```

## What each file does

| File | Library | Renderer | Bundle (gzip) | Best for |
|---|---|---|---|---|
| `leaflet.html` | Leaflet 1.9.4 | Canvas/SVG (raster) | ~40 KB | Content sites, quick embeds |
| `maplibre.html` | MapLibre GL 4.7.0 | WebGL (vector) | ~200 KB | Apps, smooth panning, custom styles |
| `openlayers.html` | OpenLayers 10.3.0 | Canvas (raster+vector) | ~350 KB | GIS tools, WMS/WFS, projections |

All three render the same location (London, 51.505°N 0.09°W, zoom 13) with a single marker.

## Notes

- OpenLayers uses `ol.proj.fromLonLat()` explicitly — coordinates have a projection, and OL surfaces it. The others hide it (usually fine for web maps, wrong for serious GIS).
- `maplibre.html` uses the OpenFreeMap hosted style (`tiles.openfreemap.org`) as a stand-in. Swap the `style` URL to point at your self-hosted Tileserver-GL instance.
- Leaflet's plugin ecosystem (Leaflet.markercluster, Leaflet.heat) works against Leaflet only. MapLibre has clustering built in; OpenLayers has its own cluster strategy.
- For raster-only use cases (satellite imagery, WMS overlays), Leaflet and OpenLayers are the right choices. For vector tiles with dynamic styling, MapLibre wins.

[Read the article](https://sumguy.com/posts/leaflet-vs-maplibre-vs-openlayers/)
