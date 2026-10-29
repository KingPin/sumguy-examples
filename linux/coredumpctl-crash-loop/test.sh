#!/usr/bin/env bash
# Builds crashy, runs it as a throwaway user unit, shows the crash with
# coredumpctl, and cleans up. No sudo, nothing outside $TMP and the user manager.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
unit=crashy-demo.service

cleanup() {
    systemctl --user stop "$unit" 2>/dev/null || true
    systemctl --user reset-failed "$unit" 2>/dev/null || true
    systemctl --user disable "$unit" 2>/dev/null || true   # removes the link
    systemctl --user daemon-reload
    rm -rf "$tmp"
}
trap cleanup EXIT

gcc -g -O0 -Wall -o "$tmp/crashy" "$here/crashy.c"
sed "s|^ExecStart=.*|ExecStart=$tmp/crashy|" "$here/crashy.service" > "$tmp/$unit"
systemctl --user link "$tmp/$unit"
systemctl --user start "$unit"

echo "== waiting for the first crash"
for _ in $(seq 1 30); do
    coredumpctl --no-pager --no-legend list "$tmp/crashy" >/dev/null 2>&1 && break
    sleep 1
done
sleep 1

echo "== systemctl status"
systemctl --user status "$unit" --no-pager || true
echo "== coredumpctl list"
coredumpctl --no-pager list "$tmp/crashy"
echo "== backtrace of the newest crash"
coredumpctl --no-pager debug "$tmp/crashy" --debugger-arguments="-batch -ex bt"
