#!/usr/bin/env bash
# Prepare an OSM PBF extract for OSRM routing.
# Usage: ./scripts/prepare.sh [mld|ch] [path/to/region-latest.osm.pbf]
#
# Defaults: MLD algorithm, Texas extract.
# MLD supports live traffic updates; CH is faster at query time for static data.

set -euo pipefail

ALGORITHM="${1:-mld}"
PBF="${2:-/opt/osrm/data/texas-latest.osm.pbf}"
DATA_DIR="$(dirname "$PBF")"
BASENAME="$(basename "$PBF" .osm.pbf)"
PROFILE="/opt/car.lua"   # profiles: /opt/car.lua, /opt/bicycle.lua, /opt/foot.lua

echo "==> Step 1: Extract (profile: $PROFILE)"
docker run --rm -v "${DATA_DIR}:/data" \
  ghcr.io/project-osrm/osrm-backend \
  osrm-extract -p "${PROFILE}" "/data/${BASENAME}.osm.pbf"

echo "==> Step 2: Partition (MLD only)"
if [ "$ALGORITHM" = "mld" ]; then
  docker run --rm -v "${DATA_DIR}:/data" \
    ghcr.io/project-osrm/osrm-backend \
    osrm-partition "/data/${BASENAME}.osrm"

  echo "==> Step 3: Customize"
  docker run --rm -v "${DATA_DIR}:/data" \
    ghcr.io/project-osrm/osrm-backend \
    osrm-customize "/data/${BASENAME}.osrm"
else
  echo "==> Step 3: Contract (CH)"
  docker run --rm -v "${DATA_DIR}:/data" \
    ghcr.io/project-osrm/osrm-backend \
    osrm-contract "/data/${BASENAME}.osrm"
fi

echo "==> Done. Start with: docker compose up -d"
echo "    If using CH, edit docker-compose.yml: --algorithm ch"
