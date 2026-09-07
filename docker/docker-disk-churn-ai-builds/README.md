# Automated Docker prune for agent build churn

Scheduled cleanup for a development host where AI coding agents rebuild Docker images
in a loop. Every rebuild that reuses a tag leaves the previous image untagged, and the
image store has no garbage collection of its own, so the orphaned layers accumulate
until the disk fills.

Companion files for the post
[Docker Ate 215GB in a Week](https://sumguy.com/docker-disk-churn-ai-builds/).

## What each file does

| File | Purpose |
| --- | --- |
| `docker-prune.service` | Type=oneshot unit running the three targeted prunes |
| `docker-prune.timer` | Daily trigger, with `Persistent=true` to catch missed runs |
| `docker-prune-user.service` | Rootless Docker variant, for `~/.config/systemd/user/` |
| `docker-prune-user.timer` | Timer for the rootless variant |
| `crontab.example` | Fallback for hosts without systemd |

## Prerequisites (tested versions)

- Docker Engine 29.6.2 with Buildx 0.29.1
- systemd 261
- An Arch based distribution, though the units are portable to any systemd distro
  (Debian, Ubuntu, Fedora, RHEL and derivatives)

`docker volume prune --all` needs API 1.42 or newer. The `label!=keep` prune filter
is older than that: it landed in API 1.29 (Docker 17.05), so any engine from the last
several years has it.

## What it prunes, and what it deliberately does not

Pruned:

- Unused and untagged images created more than 7 days ago
- Stopped containers older than a day
- Networks with nothing attached

Left alone on purpose:

- **Volumes.** `docker system prune --volumes` removes anonymous volumes not used by at
  least one container. Named volumes survive it, and only `docker volume prune --all`
  reaches those. Anonymous volumes still hold real data, because the official database
  images declare `VOLUME` in their Dockerfiles, so a `docker run postgres` with no `-v`
  writes its database into an anonymous volume. Remove that container and the volume is
  unreferenced and eligible. `docker volume prune` also supports only the `label`
  filter, with no `until`, so you cannot even age-limit the damage. Prune volumes by
  hand, after looking at `docker volume ls -f dangling=true`.
- **The build cache.** BuildKit already runs its own garbage collection against an
  ordered set of policies, so the cache is bounded without help. A blanket
  `docker system prune` also deletes `RUN --mount=type=cache` mounts, which is what
  makes the agent's next rebuild slow.

## Install (rootful Docker)

1. Copy the units into place:
   ```bash
   sudo cp docker-prune.service docker-prune.timer /etc/systemd/system/
   ```
2. Check the syntax before trusting them:
   ```bash
   systemd-analyze verify /etc/systemd/system/docker-prune.{service,timer}
   ```
3. Enable and start the timer:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now docker-prune.timer
   ```
4. Confirm the next run is scheduled:
   ```bash
   systemctl list-timers docker-prune.timer
   ```
5. Test the job now, rather than waiting for midnight:
   ```bash
   sudo systemctl start docker-prune.service
   journalctl -u docker-prune.service --no-pager
   ```

## Install (rootless Docker)

A rootless daemon is per user, so a system unit cannot reach it. Use the user units:

1. Copy them into the user unit directory:
   ```bash
   mkdir -p ~/.config/systemd/user
   cp docker-prune-user.service ~/.config/systemd/user/docker-prune.service
   cp docker-prune-user.timer ~/.config/systemd/user/docker-prune.timer
   ```
2. Enable the timer for your user:
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now docker-prune.timer
   ```
3. Allow it to run while you are logged out, otherwise the timer only fires during an
   active session:
   ```bash
   sudo loginctl enable-linger "$USER"
   ```

## Tuning

- `until=168h` filters on image **creation** time, which for a pulled image is the date
  the vendor built it upstream, not the date you pulled it. A base image built four
  months ago is eligible the moment you pull it, and the next build re-pulls it. Raise
  the value or drop `-a` if the re-pull traffic bothers you.
- Exempt anything precious by labelling it, since the units already pass
  `--filter label!=keep`:
  ```bash
  docker build --label keep=true -t myapp:golden .
  ```
- Check what a prune would be working against before changing the schedule:
  ```bash
  docker system df
  ```
