#!/bin/sh
# Set a Cachet 3.x component status.
# Status values: 1 operational, 2 performance_issues, 3 partial_outage,
#                4 major_outage, 5 unknown, 6 under_maintenance
# Usage: CACHET_TOKEN=... ./set-component-status.sh <component-id> <status> [cachet-url]
set -eu
ID="${1:?component id}"
STATUS="${2:?status 1-6}"
CACHET_URL="${3:-http://localhost:8000}"
curl -fsS -X PUT "${CACHET_URL}/api/components/${ID}" \
  -H "Authorization: Bearer ${CACHET_TOKEN}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d "{\"status\": ${STATUS}}"
