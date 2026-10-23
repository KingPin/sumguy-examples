---
name: homelab-backup-check
description: Checks whether a backup directory (restic, borg, rsync, tar dumps) is fresh by looking at the newest file's modification time. Use when the user asks if backups are current, healthy, or have stopped running.
---

# Homelab backup freshness check

Run the bundled script against the backup directory. Never guess the path: ask the user if they did not give one.

```bash
python3 scripts/check_backups.py /srv/backups --max-age-hours 26
```

## Reading the result

- Exit code 0 and `FRESH`: report the age and stop.
- Exit code 1 and `STALE`: report the age, then check the scheduler (`systemctl list-timers` or `crontab -l`) and the last job log before suggesting fixes.
- Exit code 2: the path is wrong. Ask the user.

## House rules

- Daily jobs use the default 26 hour limit (24 hours plus slack). Weekly jobs use `--max-age-hours 180`.
- The check only proves a file was written recently. For restic, also suggest `restic check`. For borg, `borg check`.
- Never delete or modify anything in the backup directory.
