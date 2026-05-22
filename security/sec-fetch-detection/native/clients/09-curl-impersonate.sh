#!/usr/bin/env bash
# curl-impersonate-chrome — TLS+header impersonation
# Binary expected at native/bin/curl_chrome116. Skipped if not present.
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$SCRIPT_DIR/bin/curl_chrome116"
if [[ ! -x "$BIN" ]]; then
  echo "skipped (curl-impersonate not installed at $BIN)"
  exit 0
fi
# curl-impersonate uses TLS handshake matching Chrome. For our http://localhost
# echo, the TLS dance is moot, but headers are still chrome-shaped.
exec "$BIN" -s "http://localhost:8080/?client=curl-impersonate-chrome" -o /dev/null
