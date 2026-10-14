#!/bin/sh
# Report a job result to the Gatus external endpoint "jobs_nightly-backup".
# Usage: PUSH_TOKEN=... ./push-backup-status.sh true|false [gatus-url]
set -eu
SUCCESS="${1:?usage: push-backup-status.sh true|false [gatus-url]}"
GATUS_URL="${2:-http://localhost:8080}"
curl -fsS -X POST \
  -H "Authorization: Bearer ${PUSH_TOKEN}" \
  "${GATUS_URL}/api/v1/endpoints/jobs_nightly-backup/external?success=${SUCCESS}"
