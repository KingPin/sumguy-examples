#!/usr/bin/env bash
# Move every regular file out of the inbox, one at a time.
# Usage: process-inbox.sh INBOX_DIR DONE_DIR
set -euo pipefail

inbox=${1:?usage: process-inbox.sh INBOX_DIR DONE_DIR}
done_dir=${2:?usage: process-inbox.sh INBOX_DIR DONE_DIR}
mkdir -p "$done_dir"

echo "triggered by ${TRIGGER_UNIT:-unknown}, path ${TRIGGER_PATH:-unknown}"

# Loop over the whole directory, not just TRIGGER_PATH: several files can
# land before the service starts, and systemd reports only one of them.
# find skips dotfiles, which is the same rule systemd uses for the watch.
find "$inbox" -maxdepth 1 -type f ! -name '.*' -print0 |
while IFS= read -r -d '' f; do
    echo "processing $(basename "$f") ($(wc -c < "$f") bytes)"
    # Real work goes here. If it fails, the file stays and the service
    # retriggers until the start limit fails the path unit (loud, not silent
    # data loss). To keep the watcher alive, mv failures to a failed/ dir instead.
    mv -- "$f" "$done_dir/"
done
