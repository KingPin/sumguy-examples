#!/usr/bin/env bash
# Send the same state + questions to Jev (OpenRouter) and Clef / Clef-flash (Workers AI).
# Usage: ./ask.sh "commit subject or any state text" [questions.json]
set -euo pipefail
STATE=${1:?usage: ./ask.sh "state text" [questions.json]}
Q=$(cat "${2:-questions.json}")

body() { jq -n --arg m "$1" --arg s "$STATE" --argjson q "$Q" '{model:$m, state:$s, questions:$q}'; }

if [[ -n "${JEV_API_KEY:-}" ]]; then
  echo "== jev"
  curl -sS https://openrouter.ai/api/alpha/decisions \
    -H "Authorization: Bearer $JEV_API_KEY" -H "Content-Type: application/json" \
    -d "$(body '~typesafe/jev-latest')" | jq '{model, answers, usage}'
fi

if [[ -n "${CLOUDFLARE_ACCOUNT_ID:-}" && -n "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  for m in clef clef-flash; do
    echo "== $m"
    curl -sS "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/ai/run/@cf/cloudflare/$m" \
      -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" \
      -d "$(body "$m")" | jq '.result // .'
  done
fi
