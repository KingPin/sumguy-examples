#!/usr/bin/env bash
# Process files dropped into an inbox, safely.
# Usage: INBOX=/srv/inbox DONE=/srv/done ./watch-inbox.sh
set -u
INBOX=${INBOX:-/srv/inbox}
DONE=${DONE:-/srv/done}
mkdir -p "$INBOX" "$DONE"

process() {
  local path=$1
  [ -f "$path" ] || return 0            # already handled, or a directory
  printf 'processing: %s (sha256 %s)\n' "$path" "$(sha256sum < "$path" | cut -c1-12)"
  mv -n -- "$path" "$DONE"/
}

# Start the monitor first so nothing is missed during the startup sweep.
# %w%f%0 with --no-newline gives NUL-separated paths: safe for spaces and newlines.
exec 3< <(inotifywait -m -q -e close_write -e moved_to \
            --no-newline --format '%w%f%0' "$INBOX")

# Catch files that were already waiting.
find "$INBOX" -maxdepth 1 -type f -print0 | while IFS= read -r -d '' f; do process "$f"; done

while IFS= read -r -d '' path <&3; do
  process "$path"
done
