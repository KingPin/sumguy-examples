#!/usr/bin/env bash
# Run all 9 client tests against a local echo server. No Docker.
# Uses existing ~/.cache/ms-playwright Chromium for puppeteer/playwright clients.

set -uo pipefail
cd "$(dirname "$0")"

CHROMIUM_BIN="${CHROMIUM_BIN:-$HOME/.cache/ms-playwright/chromium-1208/chrome-linux64/chrome}"
ECHO_HOST="${ECHO_HOST:-127.0.0.1}"
ECHO_PORT="${ECHO_PORT:-8080}"

if [[ ! -x "$CHROMIUM_BIN" ]]; then
  echo "Chromium binary not found at: $CHROMIUM_BIN"
  echo "Override with CHROMIUM_BIN=/path/to/chrome"
  exit 1
fi

mkdir -p results
: > results/raw.jsonl

# --- start echo server ---
RESULTS_PATH="$PWD/results/raw.jsonl" node ../echo-server/server.js > results/echo.log 2>&1 &
ECHO_PID=$!
echo "==> echo server started (pid=$ECHO_PID, http://$ECHO_HOST:$ECHO_PORT)"

cleanup() {
  if kill -0 "$ECHO_PID" 2>/dev/null; then
    kill "$ECHO_PID" 2>/dev/null || true
    wait "$ECHO_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# wait for echo server
for i in {1..10}; do
  if curl -fsS "http://$ECHO_HOST:$ECHO_PORT/?client=__warmup__" >/dev/null 2>&1; then
    break
  fi
  sleep 0.3
done

# --- activate python venv ---
# shellcheck disable=SC1091
source .venv/bin/activate

# --- run clients ---
declare -A STATUS

run_client() {
  local name="$1" cmd="$2"
  echo
  echo "==> [$name]"
  if eval "$cmd"; then
    STATUS[$name]="ok"
  else
    STATUS[$name]="failed (rc=$?)"
  fi
  sleep 0.5
}

export CHROMIUM_BIN

run_client "01-curl"                    "bash clients/01-curl.sh"
run_client "02-python-requests"         "python clients/02-python-requests.py"
run_client "03-puppeteer-vanilla"       "node clients/03-puppeteer-vanilla.js"
run_client "04-puppeteer-stealth"       "node clients/04-puppeteer-stealth.js"
run_client "05-playwright-vanilla"      "node clients/05-playwright-vanilla.js"

if python -c "import playwright_stealth" 2>/dev/null; then
  run_client "06-playwright-stealth"    "python clients/06-playwright-stealth.py"
else
  STATUS["06-playwright-stealth"]="skipped (playwright-stealth not installed)"
fi

if python -c "import undetected_chromedriver" 2>/dev/null; then
  run_client "07-undetected-chromedriver" "python clients/07-undetected-chromedriver.py"
else
  STATUS["07-undetected-chromedriver"]="skipped (undetected-chromedriver not installed)"
fi

run_client "08-rebrowser"               "node clients/08-rebrowser.js"
run_client "09-curl-impersonate"        "bash clients/09-curl-impersonate.sh"

# --- stop echo ---
cleanup

echo
echo "==> summary"
for k in 01-curl 02-python-requests 03-puppeteer-vanilla 04-puppeteer-stealth \
         05-playwright-vanilla 06-playwright-stealth 07-undetected-chromedriver \
         08-rebrowser 09-curl-impersonate; do
  printf "  %-32s %s\n" "$k" "${STATUS[$k]:-not-run}"
done

echo
echo "==> raw records: $(wc -l < results/raw.jsonl) lines at $PWD/results/raw.jsonl"
