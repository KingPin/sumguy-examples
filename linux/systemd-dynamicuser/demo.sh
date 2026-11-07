#!/usr/bin/env bash
# Runs every check from the post inside a throwaway Arch Linux container
# with systemd as PID 1. Nothing touches the host's systemd.
set -euo pipefail
cd "$(dirname "$0")"
NAME=dynuser-demo
IMAGE=${IMAGE:-archlinux:latest}

cleanup() { docker rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

docker run -d --name "$NAME" --privileged --cgroupns=private \
  --tmpfs /run --tmpfs /run/lock "$IMAGE" /usr/lib/systemd/systemd >/dev/null
for _ in $(seq 30); do
  state=$(docker exec "$NAME" systemctl is-system-running 2>/dev/null || true)
  [[ $state == running || $state == degraded ]] && break
  sleep 1
done

docker exec "$NAME" pacman -Sy --noconfirm --needed python >/dev/null
docker cp webdemo.service "$NAME":/etc/systemd/system/webdemo.service
docker cp webdemo-hardened.service "$NAME":/root/webdemo-hardened.service

docker exec -i "$NAME" bash -s <<'IN'
set -u
step() { printf '\n== %s\n' "$*"; }
run() { systemd-run -q --wait -P -p DynamicUser=yes "$@" 2>&1 || true; }

step "systemd version"
systemctl --version | head -1

step "1. a throwaway user"
run id

step "2. writes outside the allowed dirs fail"
run sh -c 'touch /etc/nope; touch /tmp/ok && echo "/tmp write ok (private /tmp)"'

step "3. the user exists only while the unit runs"
systemd-run -q --unit=sleeper -p DynamicUser=yes sleep 300
sleep 1
getent passwd sleeper
systemctl stop sleeper
getent passwd sleeper || echo "sleeper: gone after stop"

step "4. StateDirectory= and the private/ symlink"
mkdir -p /srv/www && echo hello > /srv/www/index.html
systemctl daemon-reload
systemctl start webdemo
sleep 1
ps -o user,uid,cmd -C python
curl -s 127.0.0.1:8080/
ls -l /var/lib/ | grep webdemo
ls -ln /var/lib/private/

step "5. same UID across restarts"
for _ in 1 2 3; do systemctl restart webdemo; systemctl show -p UID --value webdemo; done

step "6. root-only config file vs LoadCredential="
echo secret > /etc/demo.conf && chmod 600 /etc/demo.conf
run cat /etc/demo.conf
run -p LoadCredential=democonf:/etc/demo.conf sh -c 'cat "$CREDENTIALS_DIRECTORY/democonf"'

step "7. ReadWritePaths= leaves files behind"
mkdir -p /srv/shared && chmod 777 /srv/shared
run -p ReadWritePaths=/srv/shared sh -c 'touch /srv/shared/x; id -u'
ls -ln /srv/shared

step "8. migration from a static user"
useradd --system --no-create-home --shell /usr/bin/nologin olddemo
sed -e 's/^DynamicUser=yes/User=olddemo/' -e 's/webdemo/olddemo/g' -e 's/8080/8081/' \
  -e '/CacheDirectory/d;/LogsDirectory/d' /etc/systemd/system/webdemo.service \
  > /etc/systemd/system/olddemo.service
systemctl daemon-reload && systemctl start olddemo && sleep 1
echo data > /var/lib/olddemo/keep.txt && chown olddemo: /var/lib/olddemo/keep.txt
systemctl stop olddemo
sed -i 's/^User=olddemo/DynamicUser=yes/' /etc/systemd/system/olddemo.service
systemctl daemon-reload && systemctl start olddemo && sleep 1
echo "-- static user still exists:"
ps -o user,uid,cmd -C python | grep 8081
systemctl stop olddemo && userdel olddemo && systemctl start olddemo && sleep 1
echo "-- after userdel:"
ps -o user,uid,cmd -C python | grep 8081
ls -ln /var/lib/private/olddemo
journalctl -u olddemo --no-pager | grep 'Apparently' || true

step "9. systemd-analyze security scores"
sed -e 's/^DynamicUser=yes//' -e 's/webdemo/rootdemo/g' -e 's/8080/8082/' \
  /etc/systemd/system/webdemo.service > /etc/systemd/system/rootdemo.service
systemctl daemon-reload
systemd-analyze security rootdemo --no-pager | tail -1
systemd-analyze security webdemo --no-pager | tail -1
systemctl stop webdemo
cp /root/webdemo-hardened.service /etc/systemd/system/webdemo.service
systemctl daemon-reload && systemctl start webdemo && sleep 1
curl -s 127.0.0.1/
systemd-analyze security webdemo --no-pager | tail -1
IN
