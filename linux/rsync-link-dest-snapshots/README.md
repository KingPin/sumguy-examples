# rsync --link-dest: hard-link snapshot backups

Companion files for [rsync --link-dest: Snapshot Backups](https://sumguy.com/rsync-link-dest-snapshot-backups/).
It is a snapshot script plus a systemd timer. Each run writes a full-looking, dated directory, and files that did not change are hard links to the previous snapshot.

## Files

| File | What it is |
|---|---|
| `snapshot.sh` | Backup script: rsync into `.partial` with `--link-dest=../latest`, `mv` into place only on success, repoint `latest`, prune to the newest N |
| `rsync-snapshot.service` | Oneshot service that runs `snapshot.sh` at low CPU and I/O priority |
| `rsync-snapshot.timer` | Daily timer at 03:00 with `Persistent=true` so a missed run fires at next boot |
| `test.sh` | Builds a source and destination under `mktemp -d`, runs several snapshots, asserts inode sharing, new inodes for changed files, retention of deleted files, pruning, and that a failed run never moves `latest` |

## Prerequisites

- rsync 3.x, bash 4.4+, GNU coreutils and findutils, `flock`
- A destination filesystem that supports hard links (ext4, XFS, Btrfs, ZFS). Not FAT or exFAT.
- systemd, for the timer. The script and test run without it.

Tested on rsync 3.5.1 (upstream release 3.5.2 was out as of November 2026), Linux, November 2026.

## Run the test

```bash
./test.sh
```

Takes about 12 seconds (it sleeps one second between snapshots so the timestamped names differ). Everything lives in a temp dir that a trap deletes on exit.

## Use it

```bash
./snapshot.sh /home/you /srv/backups/home 14
```

Arguments: source, destination root, number of snapshots to keep (default 14). Set `RSYNC_OPTS` to change the rsync flags (default `-aH --numeric-ids --delete`). To pull over SSH, pass `user@host:/path` as the source.

## Install the timer

1. `sudo cp snapshot.sh /usr/local/bin/`
2. Edit the paths in `rsync-snapshot.service`, then `sudo cp rsync-snapshot.service rsync-snapshot.timer /etc/systemd/system/`
3. `sudo systemctl daemon-reload && sudo systemctl enable --now rsync-snapshot.timer`
4. Check with `systemctl list-timers rsync-snapshot.timer` and `journalctl -u rsync-snapshot.service`.
