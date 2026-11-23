#!/usr/bin/env bash
# Runs game-backup.sh against stub docker/zfs/restic commands and checks
# that save-on always runs, including when the snapshot fails.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/docker" <<'STUB'
#!/usr/bin/env bash
echo "rcon ${*:4}" >> "$LOG"
STUB
cat > "$tmp/zfs" <<'STUB'
#!/usr/bin/env bash
echo "zfs $*" >> "$LOG"
[ "$1" = snapshot ] && [ "${FAIL_SNAPSHOT:-0}" = 1 ] && exit 1
exit 0
STUB
cat > "$tmp/restic" <<'STUB'
#!/usr/bin/env bash
echo "restic $1" >> "$LOG"
STUB
chmod +x "$tmp"/docker "$tmp"/zfs "$tmp"/restic

run() {
  : > "$tmp/log"
  LOG="$tmp/log" PATH="$tmp:$PATH" FAIL_SNAPSHOT="$1" "$here/game-backup.sh" >/dev/null 2>&1
  echo $?
}

fail=0
check() { if grep -qx "$2" "$tmp/log"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

rc=$(run 0)
[ "$rc" -eq 0 ] && echo "ok   happy path exits 0" || { echo "FAIL happy path exit $rc"; fail=1; }
check "happy path: save-on sent" "rcon save-on"
check "happy path: restic backup ran" "restic backup"
[ "$(grep -c 'rcon save-on' "$tmp/log")" -eq 1 ] && echo "ok   save-on sent exactly once" || { echo "FAIL save-on count"; fail=1; }

rc=$(run 1)
[ "$rc" -ne 0 ] && echo "ok   failed snapshot exits non-zero" || { echo "FAIL failed snapshot exited 0"; fail=1; }
check "failed snapshot: save-on still sent" "rcon save-on"
grep -q '^restic' "$tmp/log" && { echo "FAIL restic ran after failed snapshot"; fail=1; } || echo "ok   restic skipped after failed snapshot"

exit $fail
