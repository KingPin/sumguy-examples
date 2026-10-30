# Lynis hardening audit: custom profile and weekly trend

Companion files for [Lynis: Reading a Hardening Audit Report](https://sumguy.com/lynis-hardening-audit/).

## Files

- `custom.prf`: annotated Lynis custom profile. Ten `skip-test=` lines for findings that rarely apply to a home-lab box, with a comment on each. Two use the `TEST-ID:sub-item` form (`KRNL-6000:net.ipv4.conf.all.forwarding`, `SSH-7408:port`) to skip one item and keep the rest of the test.
- `lynis-trend.sh`: runs `lynis audit system --cronjob`, then appends `date,hardening_index,warnings,suggestions,lynis_version` to a CSV. Uses `set -euo pipefail`.
- `lynis-trend.service` and `lynis-trend.timer`: systemd units that run the script weekly (Sunday 03:30, 15 min random delay, `Persistent=true`).

## Prerequisites

- Lynis, run as root. A packaged `lynis` works. For the current release, extract the tarball and point `LYNIS` at it.
- `bash`, `awk`, `date` (all standard). `systemd` for the timer.

## Versions

Tested with Lynis 3.1.7 (June 2026) in a `debian:13` container. The output excerpts in the article come from that container, running as root, with `openssh-server` installed and `sshd` started so the SSH tests had something to check.

A container is not a real host. A real host shows more findings (firewall state, boot loader, kernel modules, real SSH exposure) and a different index. The container scored 57 to 59 before any fixes.

`lynis-trend.sh` was checked with `bash -n` and shellcheck, then run twice in the container. The systemd units were checked with `systemd-analyze verify` (the only complaint was the script not being installed at `/usr/local/bin` on the checking machine). The timer itself was not run.

## Run

```bash
# Current release from the tarball
curl -fsSLO https://downloads.cisofy.com/lynis/lynis-3.1.7.tar.gz
tar xzf lynis-3.1.7.tar.gz
cd lynis
sudo ./lynis audit system --quick

# Install the profile (packaged Lynis), or copy it next to default.prf in a checkout
sudo mkdir -p /etc/lynis && sudo cp custom.prf /etc/lynis/custom.prf

# One trend row by hand (use LYNIS=... for a tarball checkout)
sudo LYNIS=/opt/lynis/lynis ./lynis-trend.sh

# Weekly timer
sudo install -m 755 lynis-trend.sh /usr/local/bin/
sudo cp lynis-trend.service lynis-trend.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now lynis-trend.timer
```

The CSV lands in `/var/lib/lynis-trend/history.csv`. Override with `CSV=` and `REPORT=`.

## Limits

- Lynis must run from its own directory when it comes from a tarball or git checkout. `lynis-trend.sh` handles that when `LYNIS` contains a slash.
- Any `lynis` command, even `lynis show version`, resets `/var/log/lynis-report.dat` to a header. The script runs the audit last for that reason. Do not run `show` commands between the audit and the parse.
- A killed run can leave `/var/run/lynis.pid`, and the next `--cronjob` run then exits 1 with "Quitting, to prevent multiple cron jobs running at the same time". Remove the file once nothing is running.
- Skipping tests does not raise the index. In the container, ten skips cut suggestions from 33 to 24 and the index went from 68 to 67.
- The script records the trend and does not alert. Compare the last two rows yourself if you want mail on a drop.
