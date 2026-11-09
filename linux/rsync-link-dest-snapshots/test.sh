#!/usr/bin/env bash
# Self-contained test for snapshot.sh. Builds everything under mktemp -d.
# shellcheck disable=SC2016,SC2034  # check() evals single-quoted expressions on purpose
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
src=$tmp/src dest=$tmp/dest
mkdir -p "$src/sub" "$dest"
fails=0
ok()   { echo "PASS: $1"; }
bad()  { echo "FAIL: $1"; fails=$((fails + 1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }
ino() { stat -c %i "$1"; }
snap() { sleep 1; "$here/snapshot.sh" "$src" "$dest" "${1:-3}" >/dev/null; }
names() { find "$dest" -mindepth 1 -maxdepth 1 -type d -name '2*' -printf '%f\n' | sort; }

echo same > "$src/same.txt"
echo old  > "$src/changed.txt"
echo gone > "$src/deleted.txt"
echo deep > "$src/sub/deep.txt"

snap; s1=$(names | tail -1)
snap; s2=$(names | tail -1)

check "second snapshot has a new name" '[ "$s1" != "$s2" ]'
check "latest points at newest snapshot" '[ "$(readlink "$dest/latest")" = "$s2" ]'
check "unchanged file shares an inode" '[ "$(ino "$dest/$s1/same.txt")" = "$(ino "$dest/$s2/same.txt")" ]'
check "link count of unchanged file is 2" '[ "$(stat -c %h "$dest/$s2/same.txt")" = 2 ]'
check "unchanged nested file shares an inode" '[ "$(ino "$dest/$s1/sub/deep.txt")" = "$(ino "$dest/$s2/sub/deep.txt")" ]'
check "directories get their own inode" '[ "$(ino "$dest/$s1/sub")" != "$(ino "$dest/$s2/sub")" ]'

echo new > "$src/changed.txt"
rm "$src/deleted.txt"
snap; s3=$(names | tail -1)

check "changed file gets a new inode" '[ "$(ino "$dest/$s2/changed.txt")" != "$(ino "$dest/$s3/changed.txt")" ]'
check "old snapshot keeps old content" '[ "$(cat "$dest/$s2/changed.txt")" = old ]'
check "new snapshot has new content" '[ "$(cat "$dest/$s3/changed.txt")" = new ]'
check "deleted source file is gone from newest snapshot" '[ ! -e "$dest/$s3/deleted.txt" ]'
check "deleted source file survives in older snapshot" '[ "$(cat "$dest/$s2/deleted.txt")" = gone ]'
check "same.txt now has 3 links" '[ "$(stat -c %h "$dest/$s3/same.txt")" = 3 ]'

# metadata-only change breaks the link under -a
chmod 600 "$src/same.txt"
snap; s4=$(names | tail -1)
check "chmod-only change breaks the hard link" '[ "$(ino "$dest/$s3/same.txt")" != "$(ino "$dest/$s4/same.txt")" ]'
check "pruned to KEEP=3" '[ "$(names | wc -l)" = 3 ]'
check "oldest snapshot was pruned" '[ ! -e "$dest/$s1" ]'
check "pruning keeps shared data readable" '[ "$(cat "$dest/$s4/sub/deep.txt")" = deep ]'

# failed run: a fake rsync that writes junk and exits 30
mkdir "$tmp/bin"
printf '#!/bin/sh\nfor last; do :; done\necho junk > "${last}junk"\nexit 30\n' > "$tmp/bin/rsync"
chmod +x "$tmp/bin/rsync"
before=$(readlink "$dest/latest"); count=$(names | wc -l)
sleep 1
if PATH="$tmp/bin:$PATH" "$here/snapshot.sh" "$src" "$dest" 3 >/dev/null 2>&1; then
    bad "failed rsync should make snapshot.sh exit non-zero"
else
    ok "failed rsync makes snapshot.sh exit non-zero"
fi
check "failed run does not move latest" '[ "$(readlink "$dest/latest")" = "$before" ]'
check "failed run adds no snapshot dir" '[ "$(names | wc -l)" = "$count" ]'
check "failed run leaves .partial behind" '[ -d "$dest/.partial" ]'

# a real run after the failure resumes into .partial and succeeds
snap; s5=$(names | tail -1)
check "recovery run becomes latest" '[ "$(readlink "$dest/latest")" = "$s5" ]'
check ".partial is gone after success" '[ ! -e "$dest/.partial" ]'
check "recovery run still links unchanged files" '[ "$(ino "$dest/$s4/sub/deep.txt")" = "$(ino "$dest/$s5/sub/deep.txt")" ]'

# missing source: real rsync fails, latest must not move
before=$(readlink "$dest/latest"); sleep 1
if "$here/snapshot.sh" "$tmp/nope" "$dest" 3 >/dev/null 2>&1; then
    bad "missing source should fail"
else
    ok "missing source fails"
fi
check "missing source does not move latest" '[ "$(readlink "$dest/latest")" = "$before" ]'

echo
if [ "$fails" -eq 0 ]; then echo "ALL TESTS PASSED"; else echo "$fails FAILED"; exit 1; fi
