# reverse-geocoding-photo-libraries

Wire PhotoPrism and Immich to a self-hosted Nominatim instance instead of the default Google Maps / paid geocoding APIs. Includes a backfill script for existing Immich libraries.

## Prerequisites

- Docker 27.x + Compose v2
- A regional Nominatim import (included in this Compose stack, or use an existing one)
- Photos directory at `./photos/` for PhotoPrism, or configure your own bind mount

## Run it

### 1. Configure passwords

```bash
cp .env.example .env   # edit all three passwords
```

### 2. Start the stack

```bash
docker compose up -d nominatim
# Wait for Nominatim import to complete (watch logs)
docker compose logs -f nominatim

# Then start the photo apps
docker compose up -d photoprism immich-server immich-db immich-redis
```

### 3. Trigger geocoding on existing PhotoPrism photos

```bash
docker compose exec photoprism photoprism places update
```

### 4. Backfill Immich

Get your API key from the Immich web UI (Account Settings → API Keys), then:

```bash
chmod +x scripts/backfill-geocoding.sh
IMMICH_HOST=http://localhost:2283 \
IMMICH_API_KEY=your-api-key-here \
./scripts/backfill-geocoding.sh
```

For a 50,000-photo library budget 30–60 minutes. Progress is visible in the Immich admin panel under Jobs.

### 5. Test Nominatim reverse geocoding directly

```bash
curl "http://localhost:8080/reverse?lat=40.7128&lon=-74.0060&format=json"
```

## Notes

- If Nominatim is on a separate Compose stack, remove the `nominatim` service block and replace the `geocoding-net` reference with an `external: true` network that bridges both stacks.
- PhotoPrism's `PHOTOPRISM_GEOCODING_API: nominatim` is a first-class option, not a workaround.
- Immich uses its bundled Natural Earth dataset by default. Setting `IMMICH_REVERSE_GEOCODING_URL` switches to Nominatim for new imports; the backfill script handles existing assets.
- The `DELAY_SECONDS=2` in the backfill script is intentional — keeps burst traffic within Nominatim's ~15–30 reverse lookups/sec capacity.

[Read the article](https://sumguy.com/posts/reverse-geocoding-photo-libraries/)
