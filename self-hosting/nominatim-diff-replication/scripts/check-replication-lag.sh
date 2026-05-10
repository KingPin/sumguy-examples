#!/usr/bin/env bash
# Check Nominatim replication lag via the status endpoint.
# Exits 1 and prints an alert if lag exceeds 48 hours.
# Wire into Prometheus Blackbox, cron, or any alerting stack.

set -euo pipefail

NOMINATIM_HOST="${NOMINATIM_HOST:-http://localhost:8080}"
MAX_LAG_SECONDS="${MAX_LAG_SECONDS:-172800}"   # 48 hours default

LAG=$(curl -s "${NOMINATIM_HOST}/status.php?format=json" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('replication_replication_age', d.get('replication_delay', 0)))")

if [ "$LAG" -gt "$MAX_LAG_SECONDS" ]; then
  echo "ALERT: Nominatim replication lag is ${LAG}s (over $((MAX_LAG_SECONDS/3600))h)"
  exit 1
fi

echo "OK: lag is ${LAG}s ($((LAG/3600))h)"
