# self-hosted-osrm-docker

Self-host OSRM (Open Source Routing Machine) for car, bicycle, or foot routing using a Geofabrik OSM extract. Supports both MLD (live traffic capable) and CH (fast static) algorithms.

## Prerequisites

- Docker 27.x + Compose v2
- 4+ GB RAM for a single US state; 8–16 GB for a full country
- Plenty of disk: a Texas extract produces ~3–5 GB of prepared graph files
- `wget` on the host

## Run it

### 1. Download an extract

```bash
chmod +x scripts/download-extract.sh
# Default: Texas
./scripts/download-extract.sh

# Or specify your own region:
./scripts/download-extract.sh https://download.geofabrik.de/europe/germany-latest.osm.pbf
```

### 2. Prepare the routing graph (MLD — recommended)

```bash
chmod +x scripts/prepare.sh
./scripts/prepare.sh mld /opt/osrm/data/texas-latest.osm.pbf
```

For CH (faster queries, no live traffic):
```bash
./scripts/prepare.sh ch /opt/osrm/data/texas-latest.osm.pbf
```

Preparation takes minutes to hours depending on extract size. The Texas extract takes ~10–15 minutes on a modern box.

### 3. Edit docker-compose.yml

Update the `.osrm` filename to match your extract, and set `--algorithm` to match what you used in the prepare step. Then start:

```bash
docker compose up -d
docker compose logs -f osrm
```

Container starts in seconds — the graph is already on disk.

### 4. Test routing

```bash
# Route from Austin to Dallas
curl "http://localhost:5000/route/v1/driving/-97.7431,30.2672;-96.7970,32.7767?steps=false&overview=full"

# Distance matrix (3 points)
curl "http://localhost:5000/table/v1/driving/-97.7431,30.2672;-96.7970,32.7767;-95.3698,29.7604"
```

## Notes

- Change the profile from `car.lua` to `bicycle.lua` or `foot.lua` in `scripts/prepare.sh` for cycling or walking routes. You must re-run the full prepare pipeline when switching profiles.
- `--max-table-size 10000` in the `docker-compose.yml` command increases the matrix endpoint limit (default 100 is tiny for real-world use).
- MLD is the algorithm to use if you plan to inject live traffic data (`osrm-customize` can be re-run with updated speeds without a full re-extract).
- For CH, swap `--algorithm mld` to `--algorithm ch` in `docker-compose.yml`.

[Read the article](https://sumguy.com/posts/self-hosted-osrm-docker/)
