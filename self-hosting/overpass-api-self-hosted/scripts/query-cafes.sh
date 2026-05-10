#!/usr/bin/env bash
# Example Overpass query: find cafes in a bounding box.
# Usage: OVERPASS_HOST=http://localhost:12345 ./scripts/query-cafes.sh

set -euo pipefail

OVERPASS_HOST="${OVERPASS_HOST:-http://localhost:12345}"

echo "==> Cafes in lower Manhattan (JSON output)"
curl -s -X POST "${OVERPASS_HOST}/api/interpreter" \
  --data-urlencode 'data=[out:json][timeout:25];
node["amenity"="cafe"](40.6,-74.05,40.75,-73.9);
out body;'

echo ""
echo "==> CSV output (name, lat, lon)"
curl -s -X POST "${OVERPASS_HOST}/api/interpreter" \
  --data-urlencode 'data=[out:csv(name, lat, lon; true; ",")][timeout:25];
node["amenity"="cafe"](40.6,-74.05,40.75,-73.9);
out;'
