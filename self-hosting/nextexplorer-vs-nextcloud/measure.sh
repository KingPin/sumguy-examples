#!/usr/bin/env bash
# Measures NextExplorer v4.0.1 vs Nextcloud 35.0.2 (SQLite) on one host.
# 1. Cold start time (3 runs, median printed by summary)
# 2. Idle memory after warm-up
# 3. Default permissions for a fresh non-admin NextExplorer user
# 4. The Nextcloud data-dir trap (uid mismatch, then stale file cache)
# Usage: ./measure.sh   (writes results/ ; needs docker, curl, python3)
set -euo pipefail
cd "$(dirname "$0")"
export ADMIN_PASS=correct-horse-battery
NX=http://localhost:3017
NC=http://localhost:8081
OUT=results; mkdir -p "$OUT"
J=$(mktemp -d)

reset() { docker compose -f compose.yaml ${1:-} down -v >/dev/null 2>&1 || true; docker run --rm -v "$PWD:/w" alpine sh -c "rm -rf /w/nx /w/files"; mkdir -p files; echo hello > files/readme.txt; }
now() { date +%s.%N; }
since() { python3 -c "print(round($(now)-$1,1))"; }
wait_nx() { until [ "$(curl -s -o /dev/null -w '%{http_code}' $NX/health)" = 200 ]; do sleep 0.2; done; }
wait_nc() { until curl -s $NC/status.php 2>/dev/null | grep -q '"installed":true'; do sleep 0.5; done; until [ "$(curl -s -o /dev/null -w '%{http_code}' $NC/login)" = 200 ]; do sleep 0.5; done; }
nx_login() { curl -s -c "$J/$1" -H 'Content-Type: application/json' -d "{\"identifier\":\"$1\",\"password\":\"$2\"}" $NX/api/auth/login >/dev/null; }
rss_mib() { docker exec "$1" sh -c 'cat /proc/[0-9]*/status 2>/dev/null' | awk '/^VmRSS/ {s+=$2} END {printf "%.0f", s/1024}'; }

echo "== host: $(nproc) cores, docker $(docker version --format '{{.Server.Version}}'), $(date -u +%F)" | tee "$OUT/summary.txt"

# 1+2. cold start, 3 runs
for run in 1 2 3; do
  reset
  t0=$(now); docker compose up -d >/dev/null 2>&1
  ( wait_nx; echo "run$run nextexplorer_ready_s $(since $t0)" ) &
  ( wait_nc; echo "run$run nextcloud_ready_s $(since $t0)" ) &
  wait
done | tee -a "$OUT/summary.txt"

# warm both with a login + a few page loads, then settle
nx_login admin@example.com $ADMIN_PASS
for i in 1 2 3; do curl -s -b "$J/admin@example.com" $NX/api/browse/Files >/dev/null; curl -s -u admin:$ADMIN_PASS -X PROPFIND $NC/remote.php/dav/files/admin/ >/dev/null; done
sleep 60
for c in nx-explorer nx-nextcloud; do
  echo "$c docker_stats_mem $(docker stats --no-stream --format '{{.MemUsage}}' $c | cut -d/ -f1 | tr -d ' ') process_rss_mib $(rss_mib $c)"
done | tee -a "$OUT/summary.txt"
docker image ls --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep -E '^(nxzai/explorer:v4.0.1|nextcloud:35.0.2-apache) ' | tee -a "$OUT/summary.txt"

# 3. non-admin defaults
curl -s -b "$J/admin@example.com" -H 'Content-Type: application/json' \
  -d '{"email":"bob@example.com","username":"bob","password":"bob-password-123","roles":["user"]}' $NX/api/users >/dev/null
nx_login bob@example.com bob-password-123
echo "bob volumes: $(curl -s -b "$J/bob@example.com" $NX/api/volumes)" | tee -a "$OUT/summary.txt"
echo "bob access on Files: $(curl -s -b "$J/bob@example.com" $NX/api/browse/Files | python3 -c 'import sys,json;print(json.load(sys.stdin)["access"])')" | tee -a "$OUT/summary.txt"
echo bob-was-here > "$J/bob.txt"
echo "bob upload: $(curl -s -o /dev/null -w '%{http_code}' -b "$J/bob@example.com" -F uploadTo=Files -F filedata=@$J/bob.txt $NX/api/upload)" | tee -a "$OUT/summary.txt"
echo "host owner of bob.txt: $(stat -c '%u:%g' files/bob.txt)" | tee -a "$OUT/summary.txt"

# 4. the Nextcloud data-dir trap
trap_run() {  # $1 = PUID:PGID
  PUID=${1%:*} PGID=${1#*:} docker compose -f compose.yaml -f compose.trap.yaml up -d --force-recreate nextexplorer >/dev/null 2>&1
  wait_nx; rm -f "$J/admin@example.com"; nx_login admin@example.com $ADMIN_PASS
  echo "from-nextexplorer-$1" > "$J/note.txt"
  code=$(curl -s -o "$J/up.out" -w '%{http_code}' -b "$J/admin@example.com" -F uploadTo=Nextcloud/admin/files -F filedata=@$J/note.txt $NX/api/upload)
  echo "trap PUID:PGID=$1 upload_http=$code body=$(head -c 160 "$J/up.out")"
}
echo "nextcloud data dir owner: $(docker exec nx-nextcloud stat -c '%u:%g %a' /var/www/html/data/admin/files)" | tee -a "$OUT/summary.txt"
trap_run 1000:1000 | tee -a "$OUT/summary.txt"
trap_run 33:33 | tee -a "$OUT/summary.txt"
listed() { curl -s -u admin:$ADMIN_PASS -X PROPFIND -H 'Depth: 1' $NC/remote.php/dav/files/admin/ | grep -c 'note.txt' || true; }
echo "on disk: $(docker exec nx-nextcloud ls /var/www/html/data/admin/files | tr '\n' ' ')" | tee -a "$OUT/summary.txt"
echo "nextcloud WebDAV lists note.txt before scan: $(listed)" | tee -a "$OUT/summary.txt"
sleep 5
echo "nextcloud WebDAV lists note.txt before scan, second look: $(listed)" | tee -a "$OUT/summary.txt"
docker exec -u www-data nx-nextcloud php occ files:scan admin 2>&1 | tail -4 | tee -a "$OUT/summary.txt"
echo "nextcloud WebDAV lists note.txt after scan: $(listed)" | tee -a "$OUT/summary.txt"


# 5. the shared-folder setup (External Storage, Local backend)
docker compose -f compose.yaml -f compose.trap.yaml down -v >/dev/null 2>&1
reset; docker run --rm -v "$PWD:/w" alpine sh -c "rm -rf /w/shared; mkdir /w/shared; chown 33:33 /w/shared"
docker compose -f compose.yaml -f compose.shared.yaml up -d >/dev/null 2>&1
wait_nx; wait_nc
occ() { docker exec -u www-data nx-nextcloud php occ "$@"; }
occ app:enable files_external >/dev/null
MID=$(occ files_external:create Shared local null::null -c datadir=/srv/shared | grep -o '[0-9]*$')
echo "external mount $MID options: $(occ files_external:list --output=json | python3 -c 'import sys,json;print([m["options"] for m in json.load(sys.stdin)])')" | tee -a "$OUT/summary.txt"
# the first PROPFIND right after creating a mount answered 404 in testing; poll until the mount shows up
n=0; until [ "$(curl -s -o /dev/null -w '%{http_code}' -u admin:$ADMIN_PASS -X PROPFIND -H 'Depth: 1' $NC/remote.php/dav/files/admin/Shared/)" = 207 ]; do n=$((n+1)); [ $n -gt 30 ] && { echo "mount never appeared"; exit 1; }; sleep 2; done
echo "mount visible after $n retries" | tee -a "$OUT/summary.txt"
rm -f "$J/admin@example.com"; nx_login admin@example.com $ADMIN_PASS
echo "from-nextexplorer-shared" > "$J/shared-note.txt"
echo "shared upload via nextexplorer: $(curl -s -o /dev/null -w '%{http_code}' -b "$J/admin@example.com" -F uploadTo=Shared -F filedata=@$J/shared-note.txt $NX/api/upload)" | tee -a "$OUT/summary.txt"
echo "check option unset, nextcloud WebDAV lists shared-note.txt: $(curl -s -u admin:$ADMIN_PASS -X PROPFIND -H 'Depth: 1' $NC/remote.php/dav/files/admin/Shared/ | grep -c 'shared-note.txt' || true)" | tee -a "$OUT/summary.txt"
occ files_external:option "$MID" filesystem_check_changes 1   # "Once per direct access"
sleep 2
echo "after filesystem_check_changes=1, nextcloud WebDAV lists shared-note.txt: $(curl -s -u admin:$ADMIN_PASS -X PROPFIND -H 'Depth: 1' $NC/remote.php/dav/files/admin/Shared/ | grep -c 'shared-note.txt' || true)" | tee -a "$OUT/summary.txt"
echo "from-nextcloud" > "$J/nc-note.txt"
echo "upload via nextcloud WebDAV: $(curl -s -o /dev/null -w '%{http_code}' -u admin:$ADMIN_PASS -T "$J/nc-note.txt" $NC/remote.php/dav/files/admin/Shared/nc-note.txt)" | tee -a "$OUT/summary.txt"
echo "nextexplorer lists: $(curl -s -b "$J/admin@example.com" $NX/api/browse/Shared | python3 -c 'import sys,json;print(sorted(i["name"] for i in json.load(sys.stdin)["items"]))')" | tee -a "$OUT/summary.txt"
echo "owners on host: $(stat -c '%n %u:%g' shared/* | tr '\n' ' ')" | tee -a "$OUT/summary.txt"

docker compose -f compose.yaml -f compose.shared.yaml down -v >/dev/null 2>&1
docker run --rm -v "$PWD:/w" alpine sh -c "rm -rf /w/nx /w/files /w/shared"
rm -rf "$J"
