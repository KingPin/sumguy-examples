#!/usr/bin/env bash
# Build the four 256 MiB test files from public sources, then check them against SHA256SUMS.
# Usage: ./fetch_data.sh   (needs Docker and about 1 GB free in ./data)
set -euo pipefail
cd "$(dirname "$0")"
SIZE=$((256 * 1024 * 1024))
IMG=compression-bench
mkdir -p data
docker build -q -t $IMG . >/dev/null

# First $SIZE bytes of a stream. Closing the pipe early is expected, so ignore SIGPIPE.
slice() { head -c $SIZE > "data/$1.tmp" || true; mv "data/$1.tmp" "data/$1"; }
in_box() { docker run --rm --entrypoint bash $IMG -c "$1"; }

# 1. Logs: Loghub "Thunderbird" syslog (sshd, kernel, cron, ...). https://zenodo.org/records/8196385
[ -f data/logs ] || { in_box 'curl -sL "https://zenodo.org/records/8196385/files/Thunderbird.tar.gz?download=1" | tar -xzO' | slice logs; } || true

# 2. Database dump: Simple English Wikipedia SQL table dumps (mysqldump format), 2026-10-01.
# Wikimedia keeps dumps for a few months. If this date is gone, use a newer one: the sizes
# and checksums change, the shape of the data does not.
WIKI=https://dumps.wikimedia.org/simplewiki/20261001/simplewiki-20261001
[ -f data/dbdump ] || { in_box "for t in page categorylinks pagelinks externallinks templatelinks linktarget change_tag; do
    curl -sL $WIKI-\$t.sql.gz | gzip -dc; done" | slice dbdump; } || true

# 3. Container image: flattened root filesystem of postgres:18 (PG 18.6), linux/amd64.
PG=postgres@sha256:885953109528ad3dfc90362b1a6f50a78620b5315be19f187753d267e484dc5b
[ -f data/rootfs ] || { docker run --rm gcr.io/go-containerregistry/crane:v0.22.1 \
    export --platform linux/amd64 $PG - | slice rootfs; } || true

# 4. Control: data that is already compressed (Big Buck Bunny, H.264 MP4). https://peach.blender.org
[ -f data/video ] || { in_box 'curl -sL https://download.blender.org/demo/movies/BBB/bbb_sunflower_1080p_30fps_normal.mp4.zip | funzip' | slice video; } || true

ls -l data
sha256sum -c SHA256SUMS
