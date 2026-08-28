#!/usr/bin/env bash
#
# Bootstraps the from-scratch Forgejo + runner stack.
#
# Generates a 40-character shared secret, derives the runner UUID from its
# first 16 characters (this is the format Forgejo's offline registration
# expects), writes .env, and prepares the data directories.

set -euo pipefail

cd "$(dirname "$0")"

if [ -e .env ]; then
  echo "==> .env already exists, reusing it"
  # shellcheck disable=SC1091
  . ./.env
else
  SHARED_SECRET="$(openssl rand -hex 20)"
  RUNNER_UUID="$(printf '%s' "${SHARED_SECRET}" \
    | python3 -c 'import sys,uuid; print(uuid.UUID(bytes=sys.stdin.read()[:16].encode()))')"

  cat > .env <<EOF
SHARED_SECRET=${SHARED_SECRET}
RUNNER_UUID=${RUNNER_UUID}
EOF
  chmod 600 .env
  echo "==> Wrote .env"
fi

mkdir -p data/forgejo data/runner/.cache

if [ "$(id -u)" -ne 0 ]; then
  echo "==> Not root. If the chown below fails, re-run with sudo."
fi
chown -R 1000:1000 data
chmod 775 data/runner/.cache
chmod g+s data/runner/.cache

cat <<'EOF'

==> Done. Now:

  1. docker compose up -d forgejo
  2. Wait for Forgejo to answer, then register the runner from the host:

       docker compose exec -u git forgejo \
         forgejo forgejo-cli actions register \
           --name demo-runner \
           --scope '' \
           --secret "$(grep SHARED_SECRET .env | cut -d= -f2)"

     --scope '' registers an instance-wide runner. Pass an org or user name to
     scope it more narrowly.

  3. docker compose up -d
  4. docker compose logs -f runner

Forgejo is on http://localhost:3000. Create the admin account with:

  docker compose exec -u git forgejo \
    forgejo admin user create --admin --username root \
      --email root@example.com --random-password

Check the runner shows as Idle at http://localhost:3000/admin/actions/runners
EOF
