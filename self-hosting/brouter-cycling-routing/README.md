# brouter-cycling-routing

Self-host BRouter for bike routing with custom cost profiles. BRouter's `.brf` profile DSL lets you tune route preference by highway type, surface, and gradient — something generic routers don't expose.

## Prerequisites

- Docker 27.x + Compose v2
- ~20–150 MB per 5°×5° segment tile (download only what you need)
- Java heap: 512 MB minimum (`JAVA_OPTS` in Compose)

## Run it

### 1. Start BRouter

```bash
docker compose up -d
docker compose logs -f brouter
# First start "fails" — expected, no segment data yet
```

### 2. Download segment tiles

Tiles are 5°×5° named by southwest corner. Figure out which ones cover your area using the [BRouter tile index](https://brouter.de/brouter/segments4/).

```bash
# Western US example
docker exec brouter wget -P /brouter/segments \
  https://brouter.de/brouter/segments4/W120_N35.rd5 \
  https://brouter.de/brouter/segments4/W115_N35.rd5 \
  https://brouter.de/brouter/segments4/W110_N30.rd5

# US Northeast example
docker exec brouter wget -P /brouter/segments \
  https://brouter.de/brouter/segments4/W75_N40.rd5

# Chicago / Midwest
docker exec brouter wget -P /brouter/segments \
  https://brouter.de/brouter/segments4/W90_N40.rd5
```

Restart after downloading tiles:
```bash
docker compose restart brouter
```

### 3. Test a route

```bash
# GeoJSON route from Chicago area point A to point B
curl "http://localhost:17777/brouter?lonlats=-87.65,41.85|-87.63,41.87&profile=trekking&alternativeidx=0&format=geojson"
```

GeoJSON response = working. Error about no segment data = wrong tiles.

### 4. Use the custom profile

The `profiles/trekking.brf` file is mounted into the container. Edit it and the change takes effect on the next request (no restart needed).

```bash
# Route using the trekking profile
curl "http://localhost:17777/brouter?lonlats=-87.65,41.85|-87.63,41.87&profile=trekking&alternativeidx=0&format=geojson"
```

## Notes

- The `.brf` cost DSL is evaluated per way segment. Lower cost = BRouter prefers that segment. Set `10000` on motorways to effectively forbid them.
- `uphillcost = 60` means 1 meter of climbing costs as much as 60 meters of flat riding. Tune this to match your fitness and bike.
- BRouter ships several built-in profiles (`trekking`, `fastbike`, `safety`, `shortest`). The `profiles/` mount lets you add or override them without rebuilding the image.
- Increase `JAVA_OPTS=-Xmx` if you load many large tiles and see OOM errors.
- BRouter's HTTP API is not authenticated — run behind a firewall or reverse proxy for public-facing setups.

[Read the article](https://sumguy.com/posts/brouter-cycling-routing/)
