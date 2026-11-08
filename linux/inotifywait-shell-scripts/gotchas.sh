#!/usr/bin/env bash
# Demonstrates each gotcha from the article. Output is what you should see.
W=$(mktemp -d); cd "$W" || exit 1
ev() { inotifywait -m -q --format '%e %f' "$@"; }

echo "--- 1. create/modify fire on a half-written file; close_write does not"
mkdir d1
ev -e create -e modify -e close_write d1 > o1 & p=$!; sleep 0.5
( echo part1; sleep 1; echo part2 ) > d1/big.txt; sleep 0.5; kill $p; cat o1

echo "--- 2. watching a single file when the editor saves via rename"
echo v1 > f.txt
ev f.txt > o2 & p=$!; sleep 0.5
echo v2 > f.txt                       # in-place write: seen
sed -i 's/v2/v3/' f.txt               # sed -i writes a new file and renames it over f.txt
sleep 0.5; echo v4 > f.txt            # later in-place write: watch is gone?
sleep 0.5; kill $p 2>/dev/null; wait $p 2>/dev/null; cat o2

echo "--- 3. same save, watching the directory"
mkdir d3; echo v1 > d3/f.txt
ev -e close_write,moved_to d3 > o3 & p=$!; sleep 0.5
sed -i 's/v1/v2/' d3/f.txt; sleep 0.5; kill $p; cat o3

echo "--- 4. exit codes"
inotifywait -q -t 1 -e close_write d3; echo "timeout exit: $?"
touch d3/x; inotifywait -q -t 1 -e delete_self d3 & sleep 0.3; rmdir d3 2>/dev/null; rm -rf d3; wait $!; echo "delete_self exit: $?"

echo "--- 5. --timefmt and %T"
mkdir d5
inotifywait -m -q -t 2 --timefmt '%H:%M:%S' --format '%T %w %f %e' -e close_write d5 & sleep 0.5
echo hi > d5/a.txt; wait

echo "--- 6. --include / --exclude"
mkdir d6
inotifywait -m -q -t 2 -e close_write --exclude '\.(tmp|swp)$' --format '%f' d6 & sleep 0.5
echo a > d6/keep.txt; echo b > d6/skip.tmp; wait

echo "--- 7. spaces and newlines in names, NUL format"
mkdir d7
inotifywait -m -q -t 2 -e close_write --no-newline --format '%w%f%0' d7 > o7 & sleep 0.5
touch "d7/my file.txt" "d7/two
lines.txt"; wait
tr '\0' '|' < o7; echo
