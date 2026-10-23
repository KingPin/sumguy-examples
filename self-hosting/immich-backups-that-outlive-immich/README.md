# Immich backups that outlive Immich

Companion files for https://sumguy.com/immich-backups-that-outlive-immich/

Makes an Immich install recoverable without Immich: originals in a readable
folder layout, album and person membership exported as plain symlink folders,
an offsite restic copy, and a README for non-technical family.

## Files

| File | What it does |
| --- | --- |
| `immich-config.json` | Storage template and automatic database dump settings (optional config file). |
| `export_metadata.py` | Calls the Immich API and builds `export/albums/<name>/` and `export/people/<name>/` symlink folders plus `albums.json` and `people.json`. Python 3 stdlib only. |
| `offsite-backup.sh` | Runs the export, then `restic backup`, `forget --prune`, and a partial `check`. |
| `FAMILY-README.md` | Template for a note the family can open without you. Fill in the placeholders. |

## Prerequisites and versions

- Immich 3.3.x (checked against the v3.3 OpenAPI spec; `/search/metadata` with `filter` and `cursor` needs 3.2.0 or newer)
- An Immich API key with `album.read`, `person.read`, and `asset.read` permissions
- Python 3.8+, restic 0.16+, bash
- Docker Compose install with `UPLOAD_LOCATION` mounted at `/data` in the container
- `export_metadata.py` was tested against a mock server that returns the documented response shapes. It was not run against a live Immich server.

## How to run

```bash
export IMMICH_URL=http://localhost:2283
export IMMICH_API_KEY=your-key
python3 export_metadata.py --out /srv/immich/export

export UPLOAD_LOCATION=/srv/immich
export RESTIC_REPOSITORY=s3:s3.example.com/family-photos
export RESTIC_PASSWORD_FILE=/etc/restic/password
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=...
restic init
./offsite-backup.sh
```

Use `--prefix-from` and `--prefix-to` if your container media path or host path differs from `/data` and `/srv/immich`. `--prefix-to` defaults to `$UPLOAD_LOCATION` when it is set, and `offsite-backup.sh` passes it explicitly.
The export folder lives inside `UPLOAD_LOCATION` so relative symlinks stay valid after a restore.
Symlinks need a Unix-like filesystem. On Windows shares, use `albums.json` instead.
