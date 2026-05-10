# Home Assistant Reverse Geocoding via Local Nominatim

Wire a self-hosted [Nominatim](https://nominatim.org/) instance into Home Assistant so `device_tracker` entities (phones, cars, GPS collars) get street/city/country names looked up locally — no GPS coords leaking to Google, Mapbox, or HERE.

Companion to the article: [Self-Hosted HA Reverse Geocoding](https://sumguy.com/posts/home-assistant-reverse-geocoding-nominatim/) on SumGuy's Ramblings.

## What it does

- Runs a small Nominatim instance on Docker, sized for a single country (or smaller)
- Provides Home Assistant YAML snippets to wire `device_tracker` entities to that local Nominatim
- Includes a sample automation that uses the reverse-geocoded address

## Prerequisites

- Docker and Docker Compose (for Nominatim)
- Home Assistant — tested on 2026.x
- A box with at least 8–16 GB RAM and ~50 GB free disk for a single-country extract

## How to run it

### 1. Start Nominatim

```bash
cp .env.example .env
# Edit .env and set NOMINATIM_PASSWORD
# Edit docker-compose.yml — change PBF_URL to your country
docker compose up -d
docker compose logs -f nominatim
```

Wait for the import to finish (1–6 hours depending on country and hardware).

### 2. Smoke test it

```bash
curl "http://localhost:8080/reverse?lat=52.5200&lon=13.4050&format=json"
```

You should get a JSON response with an `address` object.

### 3. Wire it into Home Assistant

Copy the relevant snippets from `configuration.yaml` into your Home Assistant config (or paste them into a `packages/` file). Edit:

- The hostname in URLs (`nominatim.lan` → your actual host or IP)
- `device_tracker.my_phone` → your real device tracker entity ID

Reload YAML / restart HA. Your new sensors should populate within one polling interval (5 minutes for the polling approach, or instantly for the trigger-based approach).

### 4. Add the automation

Copy `automations.yaml` snippets into your existing automations (or use the packages pattern). Adjust entity IDs to match your setup.

## Files

- `docker-compose.yml` — minimal Nominatim Docker setup
- `.env.example` — the password env var, copy to `.env`
- `configuration.yaml` — REST sensor + template sensor + rest_command snippets
- `automations.yaml` — sample automation using the reverse-geocoded address

## Notes

- Don't poll every 30 seconds. 5 minutes for polling is plenty; trigger-based is even better.
- Don't expose Nominatim to the public internet. Keep it on the LAN.
- Wrap automations in availability checks so they survive Nominatim restarts.

## Reading

- [Nominatim docs](https://nominatim.org/release-docs/latest/)
- [Home Assistant REST sensor docs](https://www.home-assistant.io/integrations/sensor.rest/)
- [SumGuy's Ramblings — Nominatim install](https://sumguy.com/posts/nominatim-self-hosted-geocoding-server/)
