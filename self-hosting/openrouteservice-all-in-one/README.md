# openrouteservice-all-in-one

Self-host OpenRouteService (ORS) for driving, cycling, and walking routing plus isochrones — all in one container. ORS uses Valhalla under the hood, handles its own graph build on first start, and exposes a clean REST API with a Swagger UI.

## Prerequisites

- Docker 27.x + Compose v2
- 2+ GB RAM (JVM heap set to 6 GB max; tune down for small hardware)
- A regional `.osm.pbf` extract — ORS builds the routing graph from it on first start
- Optional: `pip install openrouteservice` for the Python client example

## Run it

### 1. Download a regional extract

```bash
mkdir -p ors-data/files
curl -L https://download.geofabrik.de/north-america/us/california-latest.osm.pbf \
  -o ors-data/files/region.osm.pbf
```

Replace the URL with any Geofabrik extract that covers your area.

### 2. Start ORS

```bash
docker compose up -d
docker compose logs -f ors
```

Graph building runs on first start — watch for `Graphs were built successfully` in the logs. This takes 5–30 minutes depending on extract size and hardware.

### 3. Explore the API

Swagger UI is available at http://localhost:8080/ors/swagger-ui once ORS is ready.

### 4. Test with curl

```bash
# Driving route: LA → SF (lon,lat order)
curl -s "http://localhost:8080/ors/v2/directions/driving-car?start=-118.2437,34.0522&end=-122.4194,37.7749" \
  | python3 -m json.tool | grep -E '"distance"|"duration"'

# Cycling route
curl -s "http://localhost:8080/ors/v2/directions/cycling-regular?start=-118.2437,34.0522&end=-118.2200,34.0600" \
  | python3 -m json.tool

# 15-minute walking isochrone around downtown SF
curl -s -X POST "http://localhost:8080/ors/v2/isochrones/foot-walking" \
  -H "Content-Type: application/json" \
  -d '{"locations":[[-122.4194,37.7749]],"range":[900]}'
```

### 5. Python client

```bash
pip install openrouteservice
python3 ors_client.py
```

## Notes

- `JAVA_OPTS: "-Xms2g -Xmx6g"` — tune `-Xmx` based on your RAM. A California extract needs ~4–6 GB; a US state like Texas needs 3–5 GB.
- Profiles enabled: `car`, `bike-regular`, `foot-walking`. Add more in the environment block (see ORS docs for full profile list: `driving-hgv`, `cycling-road`, `foot-hiking`, `wheelchair`).
- `ors.engine.source_file` must match the `.pbf` filename inside `ors-data/files/`. If you rename the PBF, update this env var and restart.
- Graph rebuild is triggered by replacing the PBF and restarting the container (delete `ors-data/graphs/` first to force a clean build).
- ORS OpenAPI spec: http://localhost:8080/ors/openapi.json

[Read the article](https://sumguy.com/posts/openrouteservice-all-in-one/)
