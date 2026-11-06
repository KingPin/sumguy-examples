#!/usr/bin/env bash
# Runs the article's main yq commands against a scratch copy of samples/.
# Requires only Docker. The originals in samples/ are never modified.
set -euo pipefail

IMAGE="mikefarah/yq:4.54.2"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$HERE"/samples/* "$WORK"/
cd "$WORK"

# Pass NEWTAG and PORT into the container; yq can only read env vars it can see.
# 2>/dev/null hides the merge-anchor deprecation warning that compose.yml triggers.
yq() {
  docker run --rm -i --user "$(id -u):$(id -g)" -e NEWTAG -e PORT \
    -v "$WORK":/workdir "$IMAGE" "$@" 2>/dev/null
}
step() { printf '\n=== %s\n' "$*"; }

step "version"
yq --version

step "read a value, list keys"
yq '.services.web.image' compose.yml
yq '.services | keys' compose.yml
yq '.services[].image' compose.yml

step "edit: bump a tag (prints to stdout)"
yq '.services.web.image = "nginx:1.28"' compose.yml | grep image

step "edit: add an env var to a list-style service"
yq '.services.web.environment += ["DEBUG=1"]' compose.yml | sed -n '/web:/,/db:/p'

step "edit: add a key to a map-style service"
yq '.services.db.environment.LOG_LEVEL = "debug"' compose.yml | sed -n '/db:/,/cache:/p'

step "env injection with strenv"
export NEWTAG=1.28.0 PORT=9000
yq '.services.web.image = "nginx:" + strenv(NEWTAG)' compose.yml | grep 'nginx'
yq '.services.web.ports[0] = strenv(PORT) + ":80"' compose.yml | grep -A1 'ports:'

step "in-place edit (-i) on the scratch copy"
yq -i '.services.web.image = "nginx:" + strenv(NEWTAG)' compose.yml
yq '.services.web.image' compose.yml

step "k8s: select documents by kind"
yq 'select(.kind == "Deployment") | .metadata.name' k8s.yml
yq 'select(document_index == 1) | .kind' k8s.yml

step "k8s: edit only Deployments, keep every document (parenthesised form)"
yq '(select(.kind == "Deployment") | .spec.replicas) = 3' k8s.yml | grep -E '^kind|replicas'

step "k8s gotcha: select|assign without parentheses drops the Service"
yq 'select(.kind == "Deployment") | .spec.replicas = 1' k8s.yml | grep -E '^kind'

step "merge: eval-all with * (arrays are replaced)"
yq eval-all '. as $item ireduce ({}; . * $item)' base.yml override.yml

step "merge: *+ appends arrays"
yq eval-all 'select(fileIndex == 0) *+ select(fileIndex == 1)' base.yml override.yml

step "delete keys"
yq 'del(.app.features)' base.yml
yq 'del(.services.cache)' compose.yml | grep -c 'image:'

step "convert YAML to JSON and back"
yq -o json -I=0 base.yml
yq -o json base.yml | yq -p json -o yaml | head -3

step "comments survive, blank lines do not"
yq '.version = 2' comments.yml

step "markdown front matter"
yq --front-matter=process '.draft = false' post.md

step "CI: fail the build when a key is missing (-e)"
yq -e '.services.web.image' compose.yml
if yq -e '.services.nope.image' compose.yml >/dev/null; then
  echo "unexpected: key found"; exit 1
else
  echo "exit code $? as expected for a missing key"
fi

printf '\nAll steps finished.\n'
