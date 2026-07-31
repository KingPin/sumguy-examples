#!/usr/bin/env bash
# Count the exact token cost of the files you are about to hand an agent, using
# the running llama.cpp server's own tokenizer. Guessing "chars divided by four"
# is close enough to be misleading; this asks the model that will actually read
# the files.
#
# Usage:
#   ./context-budget.sh src/auth.py src/models.py AGENTS.md
#   BUDGET=32768 SERVER=http://localhost:8080 ./context-budget.sh src/*.py
#
# Requires: a running llama.cpp server (see llama-server.sh), curl, jq.

set -euo pipefail

SERVER="${SERVER:-http://localhost:8080}"
BUDGET="${BUDGET:-32768}"

# Leave room for the system prompt, the conversation, and the model's own output.
# Feeding files right up to the ceiling leaves nowhere for the actual work.
WORKING_FRACTION="${WORKING_FRACTION:-50}"

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <file> [file ...]" >&2
  exit 1
fi

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

if ! curl -sf --max-time 5 "$SERVER/health" >/dev/null; then
  echo "No llama.cpp server answering at $SERVER (start llama-server.sh first)" >&2
  exit 1
fi

count_tokens() {
  # POST /tokenize returns {"tokens":[...]}; we only need the length.
  jq -Rs '{content: .}' < "$1" \
    | curl -sf --max-time 30 "$SERVER/tokenize" \
        -H 'Content-Type: application/json' -d @- \
    | jq '.tokens | length'
}

total=0
printf '%8s  %s\n' "TOKENS" "FILE"
for f in "$@"; do
  [ -f "$f" ] || { echo "skipping $f (not a file)" >&2; continue; }
  n=$(count_tokens "$f")
  printf '%8d  %s\n' "$n" "$f"
  total=$(( total + n ))
done

allowance=$(( BUDGET * WORKING_FRACTION / 100 ))
printf '%8d  TOTAL\n' "$total"
echo
echo "Budget:    $BUDGET tokens"
echo "Allowance: $allowance tokens (${WORKING_FRACTION}% of budget reserved for files)"

if [ "$total" -gt "$allowance" ]; then
  pct=$(( total * 100 / BUDGET ))
  echo
  echo "OVER: these files alone are ${pct}% of your context window."
  echo "Drop a file, or pass an excerpt instead of the whole thing."
  exit 2
fi

echo "OK: $(( total * 100 / BUDGET ))% of the window used by files."
