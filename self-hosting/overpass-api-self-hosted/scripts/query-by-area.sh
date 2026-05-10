#!/usr/bin/env bash
# Resolve an area name via Nominatim, then query Overpass within that area.
# Usage: NOMINATIM_HOST=http://localhost:8080 OVERPASS_HOST=http://localhost:12345 \
#         AREA="Cook County Illinois" AMENITY=library ./scripts/query-by-area.sh

set -euo pipefail

NOMINATIM_HOST="${NOMINATIM_HOST:-http://localhost:8080}"
OVERPASS_HOST="${OVERPASS_HOST:-http://localhost:12345}"
AREA="${AREA:-Cook County Illinois}"
AMENITY="${AMENITY:-library}"

echo "==> Resolving area: $AREA"
RELATION_ID=$(curl -s "${NOMINATIM_HOST}/search?q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${AREA}')")&format=json" \
  | python3 -c "import sys,json; print([x for x in json.load(sys.stdin) if x['osm_type']=='relation'][0]['osm_id'])")

echo "    OSM relation ID: $RELATION_ID"
AREA_ID=$((RELATION_ID + 3600000000))

echo "==> Querying Overpass for amenity=$AMENITY in area (ID: $AREA_ID)"
curl -s -X POST "${OVERPASS_HOST}/api/interpreter" \
  --data-urlencode "data=[out:json][timeout:60];
area($AREA_ID)->.county;
node[\"amenity\"=\"${AMENITY}\"](area.county);
out body;" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for el in data['elements']:
    name = el['tags'].get('name', 'Unknown')
    print(f\"{name},{el['lat']},{el['lon']}\")
"
