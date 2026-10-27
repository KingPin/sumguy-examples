# Vaultwarden disaster recovery kit

Backup, restore, drill, and server-independent export scripts for a self-hosted Vaultwarden. Companion to <https://sumguy.com/vaultwarden-disaster-recovery/>.

## Files

| File | What it does |
| --- | --- |
| `docker-compose.yml` | Vaultwarden with a bind-mounted `./vw-data:/data` |
| `backup.sh` | `sqlite3 .backup` of the DB, plus `rsa_key*`, `attachments/`, `sends/`, `config.json`, into a dated `.tar.gz`. Optional `age` encryption, retention pruning |
| `restore.sh` | Stops the container, moves current data aside (never deletes), extracts the archive, removes stale `-wal`/`-shm`, starts the container, prints `PRAGMA integrity_check` |
| `drill.sh` | Boots a throwaway Vaultwarden from an archive on another port. Live instance untouched |
| `export-vault.sh` | Password-protected `encrypted_json` export with the Bitwarden CLI, cron friendly |

## Prerequisites

- Docker with Compose, `sqlite3` on the Docker host (the scripts run on the host, because the Vaultwarden image has no `sqlite3`), `curl`.
- Optional: `age` for archive encryption. `bw` (Bitwarden CLI) for `export-vault.sh`.
- The data dir is written by the container as root, so run `backup.sh` and `restore.sh` as root (or via `sudo`).

Tested 2026-10-27 with `vaultwarden/server:1.37.4`, sqlite3 3.54.0, Docker 29.9.2. `backup.sh` ran against a live container, `drill.sh` and `restore.sh` produced `integrity_check: ok`. `export-vault.sh` was syntax-checked only (no `bw` install or test account in the test run), and the `age` path was not run.

## Run

```bash
docker compose up -d

# nightly backup (as root)
DATA_DIR=/srv/vaultwarden/vw-data BACKUP_DIR=/backups ./backup.sh
# with encryption
AGE_RECIPIENT=age1yourpublickey... ./backup.sh

# prove the backup works, away from the live instance
./drill.sh /backups/vaultwarden-YYYYmmdd-HHMMSS.tar.gz 8099

# real restore
./restore.sh /backups/vaultwarden-YYYYmmdd-HHMMSS.tar.gz

# vault export (secrets come from the environment or a 0600 file)
BW_CLIENTID=... BW_CLIENTSECRET=... BW_PASSWORD=... EXPORT_PASSWORD=... ./export-vault.sh
```

Crontab line:

```text
17 3 * * * DATA_DIR=/srv/vaultwarden/vw-data BACKUP_DIR=/backups /srv/vaultwarden/backup.sh
```

## Notes

- Attachments are not in the `bw` JSON exports. Only `--format zip` includes them, and that path is not scripted here. `backup.sh` covers server-side attachments.
- Sends and trash items are not in any Bitwarden export.
- The archive contains `rsa_key.pem` and a plaintext `config.json`. Encrypt it before it leaves the host.
- `--password` on `bw export` is visible in the process list on a shared machine.
