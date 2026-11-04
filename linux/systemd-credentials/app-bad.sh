#!/bin/sh
# Contrast app: the secret arrives in the environment.
set -eu
echo "app: read ${#DB_PASSWORD} bytes from \$DB_PASSWORD"
echo "app: a child process sees it too: $(sh -c 'echo $DB_PASSWORD')"
sleep "${HOLD:-0}"
