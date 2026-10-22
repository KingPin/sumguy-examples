#!/usr/bin/env bash
# Usage: ./find-writes.sh <image> [extra docker run args...]
# Runs the image normally for a few seconds, then prints what it changed
# in the filesystem and the tmpfs paths to try first.
set -euo pipefail

image=${1:?usage: $0 <image> [docker run args...]}
shift
name=find-writes-$$
wait=${WAIT:-10}

trap 'docker rm -fv "$name" >/dev/null 2>&1 || true' EXIT
docker run -d --name "$name" "$@" "$image" >/dev/null
sleep "$wait"

echo "== docker diff (A=added, C=changed, D=deleted)"
docker diff "$name"

echo
echo "== directories that received new files (candidates for tmpfs or a volume)"
docker diff "$name" | awk '$1=="A"{n=split($2,p,"/"); d=""; for(i=2;i<n;i++) d=d"/"p[i]; print (d==""?"/":d)}' | sort -u
