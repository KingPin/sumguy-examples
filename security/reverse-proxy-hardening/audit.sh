#!/usr/bin/env bash
# What does this reverse proxy tell a stranger? Probes one proxy from the outside.
# Usage: audit.sh HTTP_PORT HTTPS_PORT [HOSTNAME] [ADDR]
# Needs curl and openssl. Prints a plain-text report to stdout.
set -u
hp=$1 sp=$2 host=${3:-app.example.test} addr=${4:-127.0.0.1}
res=(--resolve "$host:$sp:$addr" --resolve "other.example.test:$sp:$addr")
body=$(mktemp); trap 'rm -f "$body"' EXIT

# Status line plus the headers that identify software or set security policy.
pick() {
  grep -iE '^(HTTP/|server:|x-powered-by:|via:|alt-svc:|location:|strict-transport-security:|content-security-policy:|x-content-type-options:|x-frame-options:|referrer-policy:|permissions-policy:)' | tr -d '\r'
}
# GET with headers picked and the body saved; says so when the proxy sends nothing back.
get() {
  : > "$body"
  curl -s -m 10 -o "$body" -D - "$@" | pick
  local rc=${PIPESTATUS[0]}
  [ "$rc" -ne 0 ] && echo "no response (curl exit $rc)"
  return 0
}
peek() { echo "body: $(head -c "${1:-300}" "$body" | tr -s '\n' ' ')"; }
cert() {  # $1 = SNI name, or "none"
  local sni=(-servername "$1"); [ "$1" = none ] && sni=(-noservername)
  local pem; pem=$(openssl s_client -connect "$addr:$sp" "${sni[@]}" </dev/null 2>/dev/null | openssl x509 2>/dev/null)
  if [ -z "$pem" ]; then echo "no certificate (handshake refused)"; return; fi
  openssl x509 -noout -subject -ext subjectAltName <<<"$pem" 2>/dev/null | grep -v 'X509v3' | sed 's/^ *//'
}

echo "### 1. HTTP, correct Host"
get -H "Host: $host" "http://$addr:$hp/"

echo "### 2. HTTP, bare IP (what a scanner sees)"
get "http://$addr:$hp/"; peek 200

echo "### 3. HTTPS, correct name"
get -k "${res[@]}" "https://$host:$sp/"

echo "### 4. Forwarding headers the backend received (client sent X-Forwarded-For: 6.6.6.6)"
get -k "${res[@]}" -H 'X-Forwarded-For: 6.6.6.6' "https://$host:$sp/" >/dev/null
grep -iE '"(x-forwarded-[a-z]+|x-real-ip|forwarded|via)"' "$body" | sed 's/^ *//' || true

echo "### 5. TLS with no SNI (scanner hitting the IP)"
cert none

echo "### 6. TLS with an unknown SNI"
cert nope.example.test

echo "### 7. HTTPS, right SNI, unknown Host header"
get -k "${res[@]}" -H 'Host: other.example.test' "https://$host:$sp/"; peek 120

echo "### 8. Backend error page (/boom)"
get -k "${res[@]}" "https://$host:$sp/boom"; peek 120
