#!/usr/bin/env bash
# Download a Geofabrik OSM extract.
# Usage: ./scripts/download-extract.sh [region-url]
# Default: Texas

set -euo pipefail

PBF_URL="${1:-https://download.geofabrik.de/north-america/us/texas-latest.osm.pbf}"
DEST_DIR="/opt/osrm/data"

mkdir -p "$DEST_DIR"
echo "Downloading: $PBF_URL"
wget -c -P "$DEST_DIR" "$PBF_URL"
echo "Saved to: $DEST_DIR/$(basename "$PBF_URL")"
