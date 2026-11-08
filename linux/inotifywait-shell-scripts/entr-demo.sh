#!/usr/bin/env bash
# entr basics, non-interactive (-n) so it works without a TTY.
W=$(mktemp -d); cd "$W" || exit 1
echo 'echo v1' > app.sh; touch notes.txt

echo "--- entr reruns on change (file list on stdin, /_ is the changed file)"
ls *.sh *.txt | entr -n sh -c 'echo "ran, trigger: $0"' /_ &
p=$!; sleep 1; echo 'echo v2' > app.sh; sleep 1; kill $p; wait $p 2>/dev/null

echo "--- -r restarts a long-running process"
echo app.sh | entr -nr sh -c 'echo "server start pid $$"; sleep 100' &
p=$!; sleep 1; echo '# edit' >> app.sh; sleep 1.5; pkill -f 'entr -nr'; wait $p 2>/dev/null

echo "--- -d exits (status 2) when a new file appears"
ls | entr -nd echo changed &
p=$!; sleep 1; touch brand-new.txt; wait $p; echo "entr exit status: $?"

echo "--- the usual fix: loop it and re-list"
while sleep 0.2; do ls *.sh | entr -nd echo rerun; done &
p=$!; sleep 1; touch another.sh; sleep 1; echo '# e' >> app.sh; sleep 1; kill $p; pkill entr; wait 2>/dev/null
