# mdadm Day-2 Operations — Example Files

Companion scripts for [mdadm Day-2: Grow, Replace, Scrub](https://sumguy.com/posts/mdadm-day-2-operations/)
on [SumGuy's Ramblings](https://sumguy.com).

---

> **WARNING: These scripts modify RAID arrays.**
> Every script is written to refuse real block devices and only operate on loop devices.
> Test in a throwaway VM or loop-device environment before touching anything you care about.
> You have been warned.

---

## Files

| File | What it does |
|---|---|
| `replace-drive.sh` | Demonstrates `--fail` / `--remove` / `--add` on loop devices. Builds a 4-drive RAID 5, simulates failure, replaces, watches rebuild. |
| `grow-raid5-to-raid6.sh` | Converts a 4-drive RAID 5 (loop devices) to a 5-drive RAID 6 using `--backup-file`. Verifies after. |
| `scrub-cron.sh` | Monthly cron script. Iterates all md devices, triggers `check`, monitors until done, logs mismatch counts, emails on non-zero. |
| `mdadm-monitor.service` | systemd unit for mdadm monitor mode. Drop into `/etc/systemd/system/` if `mdmonitor.service` is not available on your distro. |

---

## Prerequisites

- Linux system with `mdadm` installed
- `losetup` available (part of `util-linux`, should be present everywhere)
- Root or sudo access
- For `scrub-cron.sh` email alerts: a working `mail` command (e.g. `mailutils` or `s-nail`)

## Quick Test Setup (Loop Devices)

The `replace-drive.sh` and `grow-raid5-to-raid6.sh` scripts create and manage their own loop devices. Just run them as root — they'll set up image files in `/tmp/`, attach loop devices, and clean up after themselves on exit or error.

```bash
sudo bash replace-drive.sh
sudo bash grow-raid5-to-raid6.sh
```

## Installing the systemd Monitor Service

1. Copy `mdadm-monitor.service` to `/etc/systemd/system/`:
   ```bash
   sudo cp mdadm-monitor.service /etc/systemd/system/
   ```

2. Add your email to `/etc/mdadm/mdadm.conf`:
   ```
   MAILADDR your-email@example.com
   ```

3. Enable and start:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now mdadm-monitor.service
   ```

4. Verify:
   ```bash
   sudo mdadm --monitor --scan --test -1
   ```

## Installing the Scrub Cron

```bash
sudo cp scrub-cron.sh /etc/cron.monthly/mdadm-scrub
sudo chmod +x /etc/cron.monthly/mdadm-scrub
```

Edit the `MAILTO` variable at the top of the script to set your email address.

---

## Tested On

- Ubuntu 24.04 LTS
- Debian 12 (Bookworm)
- mdadm 4.2+

---

## Links

- Article: https://sumguy.com/posts/mdadm-day-2-operations/
- Full series: https://sumguy.com/tags/raid/
- SMART monitoring companion: https://sumguy.com/posts/smart-monitoring-smartmontools/
