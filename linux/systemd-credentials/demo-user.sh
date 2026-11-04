#!/bin/bash
# Runs the credentials-vs-environment comparison as a normal user.
# Needs: systemd >= 256 (for `systemd-creds --user`), a running user manager.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d /tmp/credsdemo.XXXXXX)
trap 'systemctl --user stop demo-bad.service 2>/dev/null || true; rm -rf "$tmp"' EXIT

printf '%s' 'hunter2' > "$tmp/dbpass"

echo "== 1. Encrypt the secret for this user"
systemd-creds --user encrypt --name=dbpass "$tmp/dbpass" "$tmp/dbpass.cred"
echo "ciphertext starts: $(head -c 40 "$tmp/dbpass.cred")..."
echo "round trip: $(systemd-creds --user decrypt --name=dbpass "$tmp/dbpass.cred" -)"
rm "$tmp/dbpass"   # plaintext gone; only the .cred remains

echo; echo "== 2. GOOD: LoadCredentialEncrypted="
systemd-run --user --wait --pipe --quiet \
  -p LoadCredentialEncrypted=dbpass:"$tmp/dbpass.cred" \
  sh -c 'echo "CREDENTIALS_DIRECTORY=$CREDENTIALS_DIRECTORY"; ls -ld "$CREDENTIALS_DIRECTORY" "$CREDENTIALS_DIRECTORY"/dbpass; '"$here"'/app.sh'

echo; echo "== 3. BAD: Environment=DB_PASSWORD=hunter2"
systemd-run --user --quiet --unit=demo-bad -p Environment=DB_PASSWORD=hunter2 -p Environment=HOLD=20 "$here/app-bad.sh"
sleep 1
echo "-- systemctl show demo-bad -p Environment:"
systemctl --user show demo-bad.service -p Environment
pid=$(systemctl --user show demo-bad.service -p MainPID --value)
echo "-- same user reads /proc/$pid/environ:"
tr '\0' '\n' < /proc/"$pid"/environ | grep DB_PASSWORD
