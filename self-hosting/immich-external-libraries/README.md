# Immich External Libraries Kit

Config snippets for pointing Immich at photo folders you already have (a NAS share, an existing folder tree) without copying or moving the files. The originals are mounted read-only; Immich writes thumbnails and encoded video into its own upload location.

📖 **Full article:** [Immich External Libraries Without Moving](https://sumguy.com/immich-external-libraries/)

## What This Is

| File | Purpose |
|---|---|
| `docker-compose.override.yml` | Adds two read-only photo mounts to the stock `immich-server` service. Compose merges it with the stock file automatically |
| `.env.example` | Lines to merge into your existing `.env` (do not replace it): the storage and version lines from the stock `example.env`, with upload and Postgres on local disk |
| `exclusion-patterns.txt` | Extra exclusion patterns for raw files and `Raw/` folders. New libraries already exclude Synology `@eaDir`, `._*`, `#recycle`, `#snapshot`, `.stversions`, and `.stfolder` |
| `fstab.example` | Host-side NFS mount for the share, read-only, with `nofail` so a down NAS does not block boot |
| `docker-wait-for-mount.conf` | systemd drop-in so Docker starts only after the share is mounted |
| `60-inotify.conf` | Raises `fs.inotify.max_user_watches`. Only needed for the experimental file watching on a local disk |

All paths (`/srv/nas/pictures`, `/mnt/photos/...`, `nas.local`) are placeholders. Change them to yours.

## Prerequisites

- Docker and Docker Compose v2
- A working Immich install from the official `docker-compose.yml` and `example.env`
- Written for Immich v3.4.2. The override was checked with `docker compose config` against the v3.4.2 release `docker-compose.yml`; it was not run against a live library for this kit

## How to Run

1. Mount the share on the Docker host first (see `fstab.example`), add the `docker-wait-for-mount.conf` drop-in, then check it:

   ```bash
   sudo systemctl daemon-reload
   sudo mount /srv/nas/pictures
   ls /srv/nas/pictures | head
   ```

2. Copy `docker-compose.override.yml` next to Immich's `docker-compose.yml`, edit the host paths, and apply:

   ```bash
   docker compose config | grep /mnt/photos   # confirm the mounts merged
   docker compose up -d
   docker exec -it immich_server ls /mnt/photos/pictures
   ```

3. In the web UI, go to `Administration -> External Libraries`, create a library, and add `/mnt/photos/pictures` as a folder. Use the container path, not the host path.

4. Add each line from `exclusion-patterns.txt` with `Add exclusion pattern` (one pattern per dialog), then click `Scan`.

5. Set the scan schedule under `Administration -> Settings -> External Library`. On NFS or SMB, rely on the scheduled scan; file watching does not work reliably on network drives.

## Notes

- `:ro` means Immich cannot delete originals from the web UI and cannot write XMP sidecars. Metadata edits on a read-only mount fail silently. Remove `:ro` only if Immich is the only thing touching the folder.
- Moving a file inside an external library makes it a new asset on the next scan, and its Immich-side albums and descriptions are lost.
- Postgres (`DB_DATA_LOCATION`) must stay on local disk. Network shares are not supported for the database.
