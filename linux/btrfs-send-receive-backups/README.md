# Btrfs send/receive incremental backups

Companion files for [Btrfs Send/Receive: Incremental Backups](https://sumguy.com/btrfs-send-receive-incremental-backups/).

## Files

- `btrfs-incremental-send.sh`: creates a read-only timestamped snapshot, finds the newest older snapshot that also exists on the target, and sends it with `btrfs send -p` (or a full stream if none). Deletes nothing.
- `btrbk.conf`: local snapshots plus one SSH target, with retention and zstd stream compression.

## Prerequisites

- btrfs on both hosts, `btrfs-progs` on both, root (or sudo) on both ends.
- SSH key login from source to target.
- The target directory must already exist on a btrfs filesystem.
- For `btrbk.conf`: btrbk, and `zstd` on both hosts.

## Versions

Written against btrfs-progs 7.x (7.1 current as of October 2026) and btrbk 0.32.7. Not run on the author's machine: the commands follow the upstream man pages and docs.

## Run

```bash
sudo RSUDO=sudo ./btrfs-incremental-send.sh /mnt/data/files /mnt/data/.snapshots backup@backup-host /mnt/backup/files

# btrbk: dry run first, then the real thing
sudo btrbk -c btrbk.conf dryrun
sudo btrbk -c btrbk.conf run
```

The first run sends a full stream. Later runs send only the changes against the newest snapshot both sides hold.

## Limits

- The script matches parents by snapshot name only. If you renamed or rebuilt snapshots on either side, use btrbk, which tracks UUIDs.
- Nested subvolumes are not included in a snapshot.
- A send that fails midway leaves a partial, writable subvolume on the target. The script skips writable subvolumes when it picks a parent, so the next run still works. Delete the leftover with `btrfs subvolume delete`.
- With a non-root `ssh_user` (as in `btrbk.conf`) or a non-root login for the script, the target needs NOPASSWD sudo for `btrfs` (btrbk also needs `readlink` and `test`). The script uses it when you set `RSUDO=sudo`.
