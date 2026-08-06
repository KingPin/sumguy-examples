#!/usr/bin/env bash
# Verifies the rate limiter end to end against a local wrangler dev server.
#
#   ./test.sh          full run, includes the 60s window-reset wait
#   ./test.sh --quick  skips the window-reset check
#
# Exits non-zero on the first failed assertion.

set -uo pipefail

PORT="${PORT:-8799}"
BASE="http://127.0.0.1:${PORT}"
WRANGLER="./node_modules/.bin/wrangler"
LOG="$(mktemp)"
QUICK=0
[ "${1:-}" = "--quick" ] && QUICK=1

fail() { echo "FAIL: $*"; cleanup; exit 1; }

cleanup() {
  [ -n "${DEV_PID:-}" ] && kill "$DEV_PID" 2>/dev/null
  wait "${DEV_PID:-}" 2>/dev/null
}
trap cleanup EXIT

code_for() {
  # $1 = api key. Prints the HTTP status code.
  curl -s -o /dev/null -w '%{http_code}' -H "x-api-key: $1" "$BASE/"
}

echo "starting wrangler dev on :${PORT}"
$WRANGLER dev --port "$PORT" --local >"$LOG" 2>&1 &
DEV_PID=$!

# Wait for the server to answer rather than guessing with a fixed sleep.
for _ in $(seq 1 60); do
  if curl -s -o /dev/null --max-time 1 "$BASE/" 2>/dev/null; then break; fi
  if ! kill -0 "$DEV_PID" 2>/dev/null; then
    echo "--- wrangler dev died, log follows ---"; cat "$LOG"; exit 1
  fi
  sleep 1
done

echo
echo "== no api key should be rejected =="
got="$(curl -s -o /dev/null -w '%{http_code}' "$BASE/")"
[ "$got" = "401" ] || fail "expected 401 without x-api-key, got $got"
echo "  401 as expected"

echo
echo "== 30 requests under the limit should all pass (key: alpha) =="
for i in $(seq 1 30); do
  got="$(code_for alpha)"
  [ "$got" = "200" ] || fail "request $i for alpha expected 200, got $got"
done
echo "  30/30 returned 200"

echo
echo "== request 31 should be limited =="
got="$(code_for alpha)"
[ "$got" = "429" ] || fail "request 31 for alpha expected 429, got $got"
echo "  429 as expected"

echo
echo "== a different key must have its own window (key: beta) =="
got="$(code_for beta)"
[ "$got" = "200" ] || fail "first request for beta expected 200, got $got"
echo "  200, per-key isolation holds"

echo
echo "== alpha is still limited =="
got="$(code_for alpha)"
[ "$got" = "429" ] || fail "alpha expected to still be 429, got $got"
echo "  still 429"

if [ "$QUICK" = "1" ]; then
  echo
  echo "SKIPPED window-reset check (--quick)"
  echo "PASS (quick)"
  exit 0
fi

echo
echo "== after the 60s window expires alpha should recover =="
echo "  waiting 62s..."
sleep 62
got="$(code_for alpha)"
[ "$got" = "200" ] || fail "after window expiry alpha expected 200, got $got (window never reset)"
echo "  200, window reset correctly"

echo
echo "PASS"
