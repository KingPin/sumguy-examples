#!/usr/bin/env bash
# Workers AI rejects a choice question when EVERY option key contains "/".
# Expected (as of October 2026): case 1 returns HTTP 400 code 5006, case 2 succeeds.
set -euo pipefail
: "${CLOUDFLARE_ACCOUNT_ID:?}" "${CLOUDFLARE_API_TOKEN:?}"
URL="https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/ai/run/@cf/cloudflare/clef-flash"

run() {
  echo "== $1"
  curl -sS -o /tmp/clef-repro.json -w "HTTP %{http_code}\n" "$URL" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" \
    -d "{\"model\":\"clef-flash\",\"state\":\"fix the login redirect\",\"questions\":{\"file\":{\"type\":\"choice\",\"instructions\":\"Which file changed?\",\"criteria\":$2}}}"
  jq -c 'if (.errors|length)>0 then .errors else .result.answers.file.choice end' /tmp/clef-repro.json
}

run "all keys contain a slash"   '{"app/auth.py":"login and sessions","app/db.py":"database layer"}'
run "one key without a slash"    '{"app/auth.py":"login and sessions","db.py":"database layer"}'
run "workaround: dotted keys"    '{"app.auth.py":"app/auth.py: login and sessions","app.db.py":"app/db.py: database layer"}'
