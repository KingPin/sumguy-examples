#!/bin/sh
# Non-destructive test: applies myapp.conf inside a throwaway root. No sudo, nothing outside $ROOT is touched.
set -eu
cd "$(dirname "$0")"
ROOT=$(mktemp -d)
mkdir -p "$ROOT/etc" "$ROOT/srv/myapp-data" "$ROOT/var/tmp/myapp-scratch/keep"
# --root bypasses NSS and reads passwd/group inside the root, so map "myapp" to the current user.
echo "myapp:x:$(id -u):$(id -g)::/:/usr/bin/nologin" > "$ROOT/etc/passwd"
echo "myapp:x:$(id -g):" > "$ROOT/etc/group"
echo "root:x:0:0::/root:/bin/sh" >> "$ROOT/etc/passwd"
echo "root:x:0:" >> "$ROOT/etc/group"

echo "== dry run =="
systemd-tmpfiles --dry-run --create --root="$ROOT" ./myapp.conf || true
echo "== real create (inside $ROOT) =="
systemd-tmpfiles --create --root="$ROOT" ./myapp.conf
find "$ROOT" -mindepth 2 | sed "s|$ROOT||" | sort
echo "== clean pass =="
touch -d '10 days ago' "$ROOT/var/tmp/myapp-scratch/old-file" "$ROOT/var/tmp/myapp-scratch/keep/old-but-kept"
# touch -d cannot backdate ctime, and the default age check includes ctime for files.
# So the clean test uses an age-by prefix (mM = mtime only) on the same path.
systemd-tmpfiles --clean --root="$ROOT" --inline 'd /var/tmp/myapp-scratch 0750 myapp myapp mM:7d -' 'x /var/tmp/myapp-scratch/keep'
find "$ROOT/var/tmp" | sed "s|$ROOT||" | sort
rm -rf "$ROOT"
