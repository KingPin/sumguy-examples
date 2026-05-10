#!/usr/bin/env bash
# Backfill reverse geocoding for all assets in Immich.
# Requires: curl, jq
# Usage: IMMICH_HOST=http://immich:2283 IMMICH_API_KEY=yourkey ./backfill-geocoding.sh

set -euo pipefail

IMMICH_HOST="${IMMICH_HOST:-http://localhost:2283}"
API_KEY="${IMMICH_API_KEY:?Set IMMICH_API_KEY}"
BATCH_SIZE=50
DELAY_SECONDS=2

echo "Fetching all asset IDs..."
ASSET_IDS=$(curl -sf \
  -H "x-api-key: $API_KEY" \
  "$IMMICH_HOST/api/assets?take=10000&skip=0" | jq -r '.[].id')

TOTAL=$(echo "$ASSET_IDS" | wc -l)
echo "Found $TOTAL assets. Processing in batches of $BATCH_SIZE..."

batch=()
processed=0

while IFS= read -r id; do
  batch+=("\"$id\"")
  processed=$((processed + 1))

  if [ ${#batch[@]} -ge "$BATCH_SIZE" ]; then
    ids_json="[$(IFS=,; echo "${batch[*]}")]"
    curl -sf -X POST "$IMMICH_HOST/api/jobs" \
      -H "x-api-key: $API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"assetIds\": $ids_json, \"name\": \"sidecar-discovery\"}" > /dev/null
    echo "Queued batch of ${#batch[@]} (total: $processed / $TOTAL)"
    batch=()
    sleep "$DELAY_SECONDS"
  fi
done <<< "$ASSET_IDS"

# Flush remaining assets
if [ ${#batch[@]} -gt 0 ]; then
  ids_json="[$(IFS=,; echo "${batch[*]}")]"
  curl -sf -X POST "$IMMICH_HOST/api/jobs" \
    -H "x-api-key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"assetIds\": $ids_json, \"name\": \"sidecar-discovery\"}" > /dev/null
  echo "Queued final batch."
fi

echo "Done. Monitor job progress in the Immich admin panel."
