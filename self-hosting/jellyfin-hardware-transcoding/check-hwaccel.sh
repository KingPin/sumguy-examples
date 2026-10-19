#!/usr/bin/env bash
# Prove Jellyfin is using the GPU. Usage: ./check-hwaccel.sh [container-name]
# Start a transcode in a client first, then run this.
set -u
C="${1:-jellyfin}"
LOGDIR=/config/log
FF=/usr/lib/jellyfin-ffmpeg

ok()   { printf 'OK    %s\n' "$*"; }
bad()  { printf 'FAIL  %s\n' "$*"; rc=1; }
rc=0

docker inspect "$C" >/dev/null 2>&1 || { echo "container '$C' not found"; exit 2; }

echo "== Device access"
if docker exec "$C" sh -c 'ls /dev/dri/renderD* >/dev/null 2>&1'; then
  ok "/dev/dri render node visible in container"
  host_gid=$(getent group render | cut -d: -f3)
  groups=$(docker inspect -f '{{range .HostConfig.GroupAdd}}{{.}} {{end}}' "$C")
  if [ -z "$host_gid" ]; then
    bad "no 'render' group on this host; check ls -l /dev/dri for the owning group"
  else
    case " $groups " in
      *" $host_gid "*) ok "render GID $host_gid is in group_add" ;;
      *) bad "host render GID is '$host_gid' but group_add has '$groups'" ;;
    esac
  fi
  node=$(docker exec "$C" sh -c 'ls /dev/dri/renderD* | head -1')
  if docker exec "$C" sh -c "test -r $node && test -w $node"; then
    ok "$node is readable and writable by the container user"
  else
    bad "$node is not accessible to the container user (GID mismatch?)"
  fi
  echo "-- vainfo"
  docker exec "$C" "$FF/vainfo" --display drm --device "$node" 2>&1 \
    | grep -E 'Driver version|VAProfileH264|VAProfileHEVC|VAProfileAV1|VAProfileVP9|error' | head -15
elif docker exec "$C" sh -c 'command -v nvidia-smi >/dev/null'; then
  ok "nvidia-smi present in container"
  docker exec "$C" nvidia-smi --query-gpu=name,driver_version,encoder.stats.sessionCount --format=csv
else
  bad "no /dev/dri and no nvidia-smi inside the container: no GPU is passed through"
fi

echo
echo "== Latest transcode log"
log=$(docker exec "$C" sh -c "ls -t $LOGDIR/FFmpeg.Transcode-*.log 2>/dev/null | head -1")
if [ -z "$log" ]; then
  bad "no FFmpeg.Transcode-*.log in $LOGDIR (nothing transcoded yet, or the stream was direct play)"
  exit "$rc"
fi
echo "$log"
# Jellyfin passes the video encoder as "-codec:v:0 <name>". Match that token, not
# bare encoder names: the ffmpeg banner's configuration line lists libx264 too.
loghead=$(docker exec "$C" sh -c "head -c 20000 '$log'")
enc=$(printf '%s\n' "$loghead" | grep -oE -- '-codec:v:0 [a-z0-9_]+' | sort -u | tr '\n' ' ')
echo "video encoder in ffmpeg command line: ${enc:-none found}"
case "$enc" in
  *_qsv*|*_nvenc*|*_vaapi*) ok "hardware encoder in use" ;;
  *) bad "software encoder or none: the GPU is not encoding" ;;
esac
dec=$(printf '%s\n' "$loghead" | grep -oE -- '-hwaccel [a-z]+' | sort -u | tr '\n' ' ')
echo "decode hwaccel flags: ${dec:-none (the CPU decodes)}"
exit "$rc"
