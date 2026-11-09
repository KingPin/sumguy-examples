#!/usr/bin/env bash
# Installs sgtest- user units that point at a temp dir, drops files, checks the
# results, shows the retrigger-loop failure, then removes everything.
# Normal user only. No sudo. Touches nothing outside mktemp -d and
# ~/.config/systemd/user/sgtest-*.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d /tmp/sgpath-XXXXXX)
UD=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user
fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "ok: $*"; }

cleanup() {
    systemctl --user stop sgtest-inbox.path sgtest-inbox.service 2>/dev/null || true
    systemctl --user reset-failed 'sgtest-inbox.*' 2>/dev/null || true
    rm -f "$UD"/sgtest-inbox.path "$UD"/sgtest-inbox.service
    systemctl --user daemon-reload
    rm -rf "$T"
}
trap cleanup EXIT

# wait_for CMD...: poll up to 10 s
wait_for() { for _ in $(seq 100); do "$@" && return 0; sleep 0.1; done; return 1; }
n_files() { find "$1" -maxdepth 1 -type f ! -name '.*' 2>/dev/null | wc -l; }
processed_is() { [ "$(n_files "$T/processed")" -eq "$1" ]; }
# -t, not -u: output from a script that exits in milliseconds can reach the
# journal without its unit name. The $T path makes the match unique to this run.
saw_trigger() { journalctl --user -t process-inbox -o cat --no-pager | grep -qF "triggered by sgtest-inbox.path, path $T/inbox"; }
path_failed() { [ "$(systemctl --user is-active sgtest-inbox.path)" = failed ]; }

# 1. Install the kit units under sgtest- names, with %h paths swapped for $T.
mkdir -p "$UD"
for u in path service; do
    sed -e "s|%h/.local/bin/process-inbox.sh|$here/process-inbox.sh|" \
        -e "s|%h/inbox|$T/inbox|g" -e "s|%h/processed|$T/processed|g" \
        "$here/inbox.$u" > "$UD/sgtest-inbox.$u"
done
systemd-analyze --user verify "$UD/sgtest-inbox.path" "$UD/sgtest-inbox.service" \
    || fail "unit files do not verify"
systemctl --user daemon-reload
systemctl --user start sgtest-inbox.path
[ -d "$T/inbox" ] || fail "MakeDirectory=yes did not create the inbox"
ok "path unit started, MakeDirectory created the inbox"

# 2. Three files land at once: one service run, all three processed.
for i in 1 2 3; do echo "data $i" > "$T/inbox/file$i.txt"; done
wait_for processed_is 3 || fail "expected 3 processed files"
[ "$(n_files "$T/inbox")" -eq 0 ] || fail "inbox not empty"
ok "3 files dropped, 3 processed, inbox empty"

# 3. The service sees which unit triggered it.
wait_for saw_trigger \
    || fail "TRIGGER_UNIT not in journal"
ok "service saw TRIGGER_UNIT=sgtest-inbox.path"

# 4. Safe delivery: dotfiles are ignored, a rename into place triggers.
echo partial > "$T/inbox/.upload.tmp"
sleep 1
[ -e "$T/inbox/.upload.tmp" ] || fail "dotfile was processed"
mv "$T/inbox/.upload.tmp" "$T/inbox/upload.txt"
wait_for processed_is 4 || fail "renamed file not processed"
ok "dotfile ignored, rename into place processed"

# 5. Failure case: a subdirectory is never moved out, so the directory never
#    empties, the service retriggers, and the start limit fails the path unit.
mkdir "$T/inbox/stuck"
wait_for path_failed || fail "expected the path unit to fail"
echo "--- systemctl --user status sgtest-inbox.path (Active line):"
systemctl --user status sgtest-inbox.path --no-pager | grep 'Active:' || true
journalctl --user -u sgtest-inbox.path --no-pager -o cat | grep 'Failed with result' | tail -1
ok "retrigger loop ended with the path unit in failed state"

# 6. Recovery: fix the cause, reset-failed, start the path unit again.
rmdir "$T/inbox/stuck"
systemctl --user reset-failed sgtest-inbox.path sgtest-inbox.service
systemctl --user start sgtest-inbox.path
echo again > "$T/inbox/after.txt"
wait_for processed_is 5 || fail "path unit did not recover"
ok "recovered after reset-failed"

echo "ALL PASSED"
