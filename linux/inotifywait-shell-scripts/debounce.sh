#!/usr/bin/env bash
# Run a command once after a burst of changes goes quiet.
# Usage: ./debounce.sh /srv/site/src 2 ./rebuild.sh
dir=$1 quiet=$2; shift 2
inotifywait -m -r -q -e close_write,moved_to,delete --format '%w%f' "$dir" |
while IFS= read -r _first; do
  # keep draining events until $quiet seconds pass with nothing new
  while IFS= read -r -t "$quiet" _more; do :; done
  "$@"
done
