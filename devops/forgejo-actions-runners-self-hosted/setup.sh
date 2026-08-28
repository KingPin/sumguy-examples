#!/usr/bin/env bash
#
# Prepares ./data for the runner container.
#
# The runner image runs as uid 1000 and writes its config, cache and job
# workspaces into /data. A bind mount owned by root means the daemon exits
# immediately, so the ownership below is not optional.

set -euo pipefail

cd "$(dirname "$0")"

DATA_DIR="./data"
CONFIG="${DATA_DIR}/config.yml"
RUNNER_IMAGE="data.forgejo.org/forgejo/runner:13.0.0"

mkdir -p "${DATA_DIR}/.cache"

if [ -e "${CONFIG}" ]; then
  echo "==> ${CONFIG} already exists, leaving it alone"
else
  if [ -e ./config.yml.example ]; then
    echo "==> Seeding ${CONFIG} from config.yml.example"
    cp ./config.yml.example "${CONFIG}"
  else
    echo "==> Generating ${CONFIG} with forgejo-runner generate-config"
    docker run --rm "${RUNNER_IMAGE}" forgejo-runner generate-config > "${CONFIG}"
  fi
fi

# uid/gid 1000 is what the runner image runs as. Needs root on the host.
if [ "$(id -u)" -eq 0 ]; then
  chown -R 1000:1000 "${DATA_DIR}"
else
  echo "==> Not root, trying chown anyway (re-run with sudo if this fails)"
  chown -R 1000:1000 "${DATA_DIR}" || {
    echo "!! Could not chown ${DATA_DIR}. Run: sudo chown -R 1000:1000 ${DATA_DIR}"
    exit 1
  }
fi

chmod 775 "${DATA_DIR}/.cache"
chmod g+s "${DATA_DIR}/.cache"

cat <<EOF

==> Done.

Next:
  1. In Forgejo, go to Settings -> Actions -> Runners and click
     "Create new runner". Copy the UUID and Token it shows you.
  2. Edit ${CONFIG}. Under server.connections, set url, uuid and token.
     While you are in there, check that runner.labels matches the
     runs-on: values your workflows use.
  3. docker compose up -d
  4. docker compose logs -f runner

The runner should appear as Idle on the same Runners page.
EOF
