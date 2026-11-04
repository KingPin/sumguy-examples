#!/bin/sh
# Demo app: reads its secret from the credentials directory, never from env.
set -eu
secret=$(cat "$CREDENTIALS_DIRECTORY/dbpass")
echo "app: read ${#secret} bytes from \$CREDENTIALS_DIRECTORY/dbpass"
echo "app: env contains the password? $(env | grep -c "$secret" || true) match(es)"
