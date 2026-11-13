#!/usr/bin/env bash
# Builds the docker init output ("generated") and the fixed version of each
# sample app, then measures: BuildKit check warnings, image size, whether a
# planted .env.production ends up in the image, what runs as PID 1, and how
# long `docker stop` takes (10 s means Docker gave up and sent SIGKILL).
set -euo pipefail
cd "$(dirname "$0")"

declare -A PORT=([python]=8000 [node]=3000 [go]=8080)

cleanup() { rm -f python/.env.production node/.env.production go/.env.production; }
trap cleanup EXIT

printf '%-7s %-10s %-9s %-8s %-11s %-34s %-8s %s\n' \
  lang variant warnings size env-leak pid1 stop_s exit
for lang in python node go; do
  echo 'DB_PASSWORD=hunter2' > "$lang/.env.production"
  variants="generated"; [ -f "$lang/Dockerfile.execonly" ] && variants+=" execonly"
  for variant in $variants fixed; do
    df="Dockerfile.$variant"; [ "$variant" = fixed ] && df=Dockerfile
    tag="dinit-$lang:$variant"

    # execonly shares the fixed .dockerignore; generated uses Dockerfile.generated.dockerignore
    warnings=$(docker build --check -f "$lang/$df" "$lang" 2>&1 | grep -c '^WARNING:' || true)
    docker build -q -t "$tag" -f "$lang/$df" "$lang" >/dev/null
    size=$(docker image inspect "$tag" --format '{{.Size}}' | awk '{printf "%.0fMB", $1/1000/1000}')

    leak=$(docker run --rm --entrypoint sh "$tag" -c \
      'find / -xdev -name .env.production 2>/dev/null | head -1')
    [ -n "$leak" ] && leak="LEAKED" || leak="clean"

    cid=$(docker run -d "$tag")
    ip=$(docker inspect "$cid" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
    for _ in $(seq 1 30); do
      curl -fs "http://$ip:${PORT[$lang]}/" >/dev/null && break
      sleep 0.5
    done
    pid1=$(docker top "$cid" -o pid,args | sed -n 2p | awk '{$1=""; sub(/^ /,""); print}' | cut -c1-34)

    start=$(date +%s%N)
    docker stop "$cid" >/dev/null
    stop_s=$(awk -v ns=$(( $(date +%s%N) - start )) 'BEGIN{printf "%.1f", ns/1e9}')
    code=$(docker inspect "$cid" --format '{{.State.ExitCode}}')
    docker rm "$cid" >/dev/null

    printf '%-7s %-10s %-9s %-8s %-11s %-34s %-8s %s\n' \
      "$lang" "$variant" "$warnings" "$size" "$leak" "$pid1" "$stop_s" "$code"
  done
  rm -f "$lang/.env.production"
done
