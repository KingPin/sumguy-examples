#!/usr/bin/env bash
cd "$(dirname "$0")"
dpkg -s inotify-tools entr | grep -E '^(Package|Version)'
echo "max_user_watches: $(cat /proc/sys/fs/inotify/max_user_watches)"
bash ./gotchas.sh
bash ./entr-demo.sh

echo "--- watch-inbox.sh"
export INBOX=$(mktemp -d) DONE=$(mktemp -d)
echo preexisting > "$INBOX/old.txt"
./watch-inbox.sh & p=$!; sleep 1
( echo partial; sleep 1; echo rest ) > "$INBOX/slow upload.txt"
echo x > /tmp/staged.bin && mv /tmp/staged.bin "$INBOX/renamed-in.bin"
sleep 1.5; kill $p; pkill inotifywait; ls "$DONE"

echo "--- debounce.sh (10 saves, one rebuild)"
S=$(mktemp -d)
./debounce.sh "$S" 1 ./rebuild.sh & p=$!; sleep 0.5
for i in $(seq 10); do echo $i > "$S/f$i"; sleep 0.1; done
sleep 2.5; kill $p; pkill inotifywait
