# systemd-tmpfiles: tmpfiles.d vs unit directory directives

Companion files for [systemd-tmpfiles: Runtime and Cache Dirs](https://sumguy.com/systemd-tmpfiles/).
It shows the two ways to get a directory to exist before your service starts, and how to test the tmpfiles.d way without touching your system.

## Files

| File | What it is |
|---|---|
| `myapp.conf` | A tmpfiles.d file: age-cleaned scratch dir, upload staging dir, `f`, `L+`, `Z`, `x`, and a boot-only `r!` line |
| `myapp.service` | A unit that gets `/run/myapp`, `/var/lib/myapp`, `/var/cache/myapp`, `/var/log/myapp`, and `/etc/myapp` from `RuntimeDirectory=`, `StateDirectory=`, `CacheDirectory=`, `LogsDirectory=`, `ConfigurationDirectory=` |
| `test.sh` | Applies `myapp.conf` inside a throwaway directory as a normal user, then runs a clean pass |

## Prerequisites

- systemd 261 or newer for the `--inline` flag used in `test.sh` (the rest works on older versions; `--dry-run` needs 256, and its `-n` short form needs 262)
- A normal user account. No sudo needed.

Tested on systemd 262.

## Run it safely

```bash
./test.sh
```

The script builds a temporary root with a fake `myapp` user mapped to your own UID, runs a dry run, creates the paths, backdates a file, and cleans it. Everything lives under `mktemp -d` and is deleted at the end.

Check the unit file syntax:

```bash
systemd-analyze verify ./myapp.service
```

Show every tmpfiles.d file that applies on your machine (read-only):

```bash
systemd-tmpfiles --cat-config | less
```

## Installing for real

1. Copy `myapp.conf` to `/etc/tmpfiles.d/` and create the `myapp` user first.
2. Preview: `sudo systemd-tmpfiles --dry-run --create /etc/tmpfiles.d/myapp.conf`
3. Apply: `sudo systemd-tmpfiles --create /etc/tmpfiles.d/myapp.conf`
4. Copy `myapp.service` to `/etc/systemd/system/` and run `sudo systemctl daemon-reload`.
