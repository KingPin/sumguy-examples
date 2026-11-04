# systemd credentials vs Environment=

Companion files for the post [systemd Credentials](https://sumguy.com/systemd-credentials/).

## What it does

Runs the same fake secret through two paths and shows the difference:

- `LoadCredentialEncrypted=`: secret stored encrypted, delivered as a 0400 file under `$CREDENTIALS_DIRECTORY`.
- `Environment=DB_PASSWORD=...`: secret visible in `systemctl show` and in the process environment.

## Files

| File | Purpose |
| --- | --- |
| `demo-user.sh` | Runs the whole comparison under `systemd-run --user`. No root. |
| `app.sh` | Demo app. Reads `$CREDENTIALS_DIRECTORY/dbpass`. |
| `app-bad.sh` | Contrast app. Reads `$DB_PASSWORD`. |
| `myapp.service` | System unit using `LoadCredentialEncrypted=` (needs root to install). |
| `myapp-bad.service` | The `Environment=` version to avoid. |

## Prerequisites

- Linux with systemd and a running user manager (`systemctl --user status` works).
- `systemd-creds --user` needs a systemd new enough to have the `--user` flag (the man page says "Added in version 256").
- Tested on systemd 262.1 on Arch Linux.

## Run

```bash
./demo-user.sh
```

Expected: the encrypted round trip prints `hunter2`, the good run shows a `dr-x------` directory and a `-r--------` file with no password in the environment, and the bad run prints `Environment=DB_PASSWORD=hunter2` from `systemctl show`.

Temp files live in `/tmp/credsdemo.*` and are removed on exit.

## System-service setup

```bash
sudo mkdir -p /etc/myapp
printf '%s' 'hunter2' | sudo systemd-creds encrypt --name=dbpass - /etc/myapp/dbpass.cred
sudo install -D -m 0755 app.sh /opt/myapp/app.sh
sudo cp myapp.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl start myapp
```

Encrypted credentials are bound to the machine (host key, plus the TPM2 when present). Re-encrypt on the new host after a migration.
