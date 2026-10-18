#!/usr/bin/env bash
set -euo pipefail

dir=/var/lib/fw-snapshots
mkdir -p "$dir"
nft -j list ruleset > "$dir/$(date +%F).json"
