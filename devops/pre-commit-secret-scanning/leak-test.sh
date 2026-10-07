#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cd "$tmp"
git init -q
git config user.name "Leak Test"
git config user.email "leak-test@example.com"
cp "$here/.pre-commit-config.yaml" "$here/.gitleaks.toml" .
pre-commit install

# Fake token: right shape, not a real credential.
echo 'RENOVATE_GITHUB_COM_TOKEN=ghp_aB3dE5gH7jK9mN1pQ3sT5vW7yZ9bC1dE3fG5' > config.env
git add config.env

if git commit -m "add config" ; then
  echo "FAIL: the commit went through, no hook caught the fake token"
  exit 1
else
  echo "OK: the hook blocked the commit"
fi
