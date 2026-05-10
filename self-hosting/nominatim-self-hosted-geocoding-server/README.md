# Nominatim: Self-Hosted Geocoding Server

A working Docker Compose setup for self-hosting [Nominatim](https://nominatim.org/), the OpenStreetMap geocoder. Uses the `mediagis/nominatim` community image with a regional PBF extract from Geofabrik.

Companion to the article: [Nominatim: Self-Hosted Geocoding](https://sumguy.com/posts/nominatim-self-hosted-geocoding-server/) on SumGuy's Ramblings.

## What it does

- Downloads a regional OpenStreetMap PBF (default: North America from Geofabrik)
- Imports it into the bundled PostgreSQL + PostGIS
- Exposes the standard Nominatim REST API on port 8080
- Configured with a replication URL so you can pull periodic OSM updates

## Prerequisites

- Docker and Docker Compose
- Tested with: `mediagis/nominatim:4.5`
- A box with at least 16 GB RAM, 1 TB NVMe (for North America scale)
- 6–18 hours of patience for the initial import (depends on hardware and extract)

## How to run it

1. Copy `.env.example` to `.env` and set a real `NOMINATIM_PASSWORD`:

   ```bash
   cp .env.example .env
   # edit .env
   ```

2. Optional — change the `PBF_URL` and `REPLICATION_URL` in `docker-compose.yml` to a smaller regional extract if you don't need the whole continent. Geofabrik publishes country and subregional extracts at https://download.geofabrik.de/.

3. Bring it up:

   ```bash
   docker compose up -d
   docker compose logs -f nominatim
   ```

4. Wait for the import to finish. The container exposes port 8080 once it's ready.

5. Smoke test:

   ```bash
   curl "http://localhost:8080/search?q=1600+Pennsylvania+Ave+Washington&format=json"
   curl "http://localhost:8080/reverse?lat=38.8977&lon=-77.0365&format=json"
   ```

## Updating the data

```bash
# Run a one-shot replication update
docker exec nominatim sudo -u nominatim nominatim replication --once

# Or as a background daemon inside the container
docker exec -d nominatim sudo -u nominatim nominatim replication
```

## Notes

- `shm_size: 1gb` is not optional — lower values OOM the import.
- The flatnode volume is mounted separately because the file can grow large (75+ GB for the planet).
- Don't expose port 8080 directly to the public internet. Put a reverse proxy with rate limiting in front.

## Reading

- [Nominatim docs](https://nominatim.org/release-docs/latest/)
- [mediagis/nominatim README](https://github.com/mediagis/nominatim-docker)
- [SumGuy's Ramblings — Nominatim hardware sizing](https://sumguy.com/posts/nominatim-hardware-sizing/)
