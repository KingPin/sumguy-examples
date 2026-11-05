#!/usr/bin/env bash
# Which security headers does each kind of response carry, and how many copies of each?
# Usage: headers.sh HTTPS_PORT [HOSTNAME] [ADDR]   Needs curl.
set -u
sp=$1 host=${2:-app.example.test} addr=${3:-127.0.0.1}
want='strict-transport-security|content-security-policy|x-frame-options|x-content-type-options|referrer-policy|permissions-policy|x-xss-protection|cross-origin-opener-policy|cache-control'
for path in / /app /static/a.css /missing /boom; do
  echo "### GET $path"
  curl -s -k -m 10 -o /dev/null -D - --resolve "$host:$sp:$addr" "https://$host:$sp$path" \
    | tr -d '\r' | grep -iE "^(HTTP/|($want):)" | sort -f | uniq -ci | sed 's/^ *//'
done
