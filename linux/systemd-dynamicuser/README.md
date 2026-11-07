# systemd DynamicUser= demo

Companion files for the post [systemd DynamicUser: No useradd Needed](https://sumguy.com/systemd-dynamicuser/).

## What it does

`demo.sh` starts a throwaway Arch Linux container with systemd as PID 1 and runs every check from the post inside it:

1. A `DynamicUser=yes` transient unit gets a UID from 61184-65519 and no `/etc/passwd` entry.
2. Writes outside the allowed directories fail (`ProtectSystem=strict` is implied).
3. The user resolves through `getent` only while the unit runs.
4. `StateDirectory=` lands in `/var/lib/private/` behind a symlink.
5. The UID stays the same across restarts of the same unit.
6. A root-only `0600` file is unreadable, and `LoadCredential=` fixes that.
7. `ReadWritePaths=` leaves files owned by a bare numeric UID behind.
8. Migrating a unit from a static `useradd` account to `DynamicUser=yes`.
9. `systemd-analyze security` scores for a root unit, a plain `DynamicUser=` unit, and the hardened unit.

Nothing touches the host's systemd. The container is removed on exit.

## Files

| File | Purpose |
| --- | --- |
| `demo.sh` | Runs all checks in a disposable container. |
| `webdemo.service` | Minimal `DynamicUser=` unit: Python `http.server` on 127.0.0.1:8080 with state, cache, and logs dirs. |
| `webdemo-hardened.service` | Same service on port 80 with `CAP_NET_BIND_SERVICE` and extra sandboxing. Scores 1.4 in `systemd-analyze security`. |
| `results.txt` | Output of one run. |

## Prerequisites

- Docker with cgroup v2. The container runs `--privileged` because systemd needs to manage cgroups and mounts inside it.
- Tested on Docker 29.9.2, `archlinux:latest` with systemd 262.1, host kernel 7.3.
- On systemd 257 and later, `StateDirectory=` with `DynamicUser=` uses id-mapped mounts, so the host sees the directory as owned by `nobody` (65534). On systemd 252 (Debian 12) the host sees the dynamic UID instead. Both were one-off checks (Debian 13 with systemd 257 showed `nobody`), not part of `demo.sh`.

## Run

```bash
./demo.sh
```

Compare your output with `results.txt`. The UIDs for the same unit names matched across two fresh containers in testing (webdemo got 62871 both times). systemd derives its first-choice UID from the unit name, then picks another if that one is taken.

## Caveat on port 80

Docker sets `net.ipv4.ip_unprivileged_port_start=0` inside containers, so the hardened unit binds port 80 there even without the capability. On a normal host the value is 1024, and `AmbientCapabilities=CAP_NET_BIND_SERVICE` is what makes port 80 work.

## Install on a real host

```bash
sudo mkdir -p /srv/www && echo hello | sudo tee /srv/www/index.html
sudo cp webdemo.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now webdemo
curl 127.0.0.1:8080/
```

The unit calls `/usr/bin/python`. On Debian and Ubuntu, change it to `/usr/bin/python3`.
