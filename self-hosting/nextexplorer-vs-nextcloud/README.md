# NextExplorer vs Nextcloud: test kit

Companion code for [NextExplorer vs Nextcloud for Plain Files](https://sumguy.com/nextexplorer-vs-nextcloud/) on SumGuy's Ramblings.

Runs NextExplorer and Nextcloud side by side on one Docker host and measures:

1. Cold start time to a usable login page (3 runs per invocation).
2. Idle memory after a short warm-up (`docker stats`).
3. What a freshly created non-admin NextExplorer user can do with the default settings.
4. What happens when you mount Nextcloud's data directory into NextExplorer (the trap).
5. The setup that works: one neutral folder, mounted into both, with Nextcloud reading it through the External Storage app.

## Files

| File | What it is |
|---|---|
| `compose.yaml` | NextExplorer v4.0.1 + Nextcloud 35.0.2 (Apache image, SQLite). One container each. |
| `compose.trap.yaml` | Override that mounts Nextcloud's `data/` into NextExplorer as `/mnt/Nextcloud`. Test only. |
| `compose.shared.yaml` | Override that mounts `./shared` into both containers and runs NextExplorer as uid/gid 33. |
| `measure.sh` | Runs every test and writes `results/summary.txt`. |
| `results/` | Raw output from the runs quoted in the article. |

## Prerequisites

- Docker Engine with Compose v2 (tested on Docker 29.9.2). The `subpath` volume option in `compose.trap.yaml` needs an Engine and Compose recent enough to support volume subpaths.
- `curl` and `python3` on the host.
- Ports 3017 and 8081 free.

Tested versions: `nxzai/explorer:v4.0.1`, `nextcloud:35.0.2-apache`.

## Run it

```bash
./measure.sh
cat results/summary.txt
```

The script tears everything down (including volumes) between stages and at the end. It takes about four minutes. The default admin password is `correct-horse-battery`; override with `ADMIN_PASS=...`.

To just poke at both apps:

```bash
docker compose up -d
# NextExplorer: http://localhost:3017  (admin@example.com / correct-horse-battery)
# Nextcloud:    http://localhost:8081  (admin / correct-horse-battery)
docker compose down -v
```

## Results (2026-11-13, 16-core desktop, Docker 29.9.2)

Five full runs, 15 cold starts per app (`results/all_runs.txt`):

| | NextExplorer v4.0.1 | Nextcloud 35.0.2 (SQLite) |
|---|---|---|
| Image size | 390 MB | 1.48 GB |
| Cold start to login page | 1.2 to 3.9 s (median 1.6) | 9.5 to 71.6 s (median 12.6) |
| Idle memory (`docker stats`) | 60 to 86 MiB | 185 to 242 MiB |

Nextcloud's cold start includes the first-boot installer, which is why it swings so much. Its memory number is the web container only: no MariaDB/Postgres, no Redis, no cron container. A real install adds those.

Findings from `results/summary.txt`:

- A new non-admin NextExplorer user gets read, write, delete and share on every volume while `USER_VOLUMES` is `false` (the default).
- NextExplorer at the default PUID/PGID (1000:1000) cannot write into Nextcloud's data directory (owned by uid 33): upload returns HTTP 403.
- With PUID/PGID 33:33 the upload succeeds, and Nextcloud does not list the file until `occ files:scan` runs.
- In the shared-folder setup, a mount created with `occ files_external:create` did not pick up NextExplorer's upload until the mount's `filesystem_check_changes` option was set to `1` ("Once per direct access"). After that, both apps saw each other's files with no scan.

## Clean up

```bash
docker compose -f compose.yaml -f compose.trap.yaml -f compose.shared.yaml down -v
docker run --rm -v "$PWD:/w" alpine rm -rf /w/nx /w/files /w/shared
```
