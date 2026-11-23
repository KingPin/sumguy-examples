# backing-up-a-live-game-server-safely

Back up a running Minecraft Java server without a torn world: pause saves over RCON (`save-off`, `save-all flush`), take a ZFS snapshot inside that pause, turn saving back on, then let restic read the snapshot while the server runs normally.

Full writeup: [sumguy.com/backing-up-a-live-game-server-safely/](https://sumguy.com/backing-up-a-live-game-server-safely/)

## Files

- `game-backup.sh`: the snapshot script from the post. Uses `docker exec mc rcon-cli` (the `itzg/minecraft-server` image ships `rcon-cli`), a ZFS dataset, and restic. An `EXIT` trap sends `save-on` even if the snapshot fails.
- `test-trap.sh`: runs `game-backup.sh` against stub `docker`, `zfs`, and `restic` commands and checks that `save-on` is always sent, including on a failed snapshot. Needs only bash.
- `docker-compose.yml`: the container alternative. `itzg/minecraft-server` plus the `itzg/mc-backup` sidecar with `BACKUP_METHOD=restic`. The sidecar keeps saves off for the whole backup read, so it suits small worlds.

## Prerequisites

- Docker with Compose v2.
- For `game-backup.sh`: the server's `/data` on its own ZFS dataset (the script assumes `tank/games/minecraft` mounted at `/srv/minecraft`), restic 0.17 or newer, and root (or `zfs allow` delegation) for `zfs snapshot` / `zfs destroy`.
- A restic repository already created with `restic init`.
- Tested: `test-trap.sh` with bash 5.3. The script itself follows restic 0.20 and OpenZFS 2.x command syntax.

## Run it

Snapshot script:

```bash
./test-trap.sh                        # sanity check, no root needed
sudo install -m 755 game-backup.sh /usr/local/bin/
sudo /usr/local/bin/game-backup.sh    # edit CONTAINER, DATASET, MOUNT, RESTIC_* first
```

Schedule it hourly from cron or a systemd timer. Wrap it in `flock` if runs could overlap.

Compose sidecar:

```bash
mkdir -p secrets && openssl rand -hex 24 > secrets/rcon_pass.txt && openssl rand -hex 24 > secrets/restic_pass.txt
docker compose up -d
docker compose logs -f backups
```

## Test the restore

```bash
restic snapshots --tag minecraft
restic restore latest --tag minecraft --target /tmp/mc-restore
find /tmp/mc-restore -maxdepth 6 -name level.dat
```

Boot a throwaway `itzg/minecraft-server` container on another port against the restored directory and walk around your base before you trust the backups.
