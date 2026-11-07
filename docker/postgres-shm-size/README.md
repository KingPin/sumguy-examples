# Postgres in Docker: the shm_size gotcha

Companion kit for [Postgres in Docker: The shm_size Gotcha](https://sumguy.com/postgres-docker-shm-size/).

Docker gives every container a 64MB `/dev/shm`. Postgres parallel queries allocate
dynamic shared memory there (`dynamic_shared_memory_type = posix`). A parallel hash
join with a modest `work_mem` outgrows 64MB and fails with:

```
ERROR:  could not resize shared memory segment "/PostgreSQL.NNNN" to 67244032 bytes: No space left on device
```

## What it does

`run.sh` starts four copies of `postgres:18.6`, loads a 5M-row table, and runs the
same parallel hash join (`work_mem = 64MB`, default 2 parallel workers) on each:

| Service      | Setup                                           | Result                          |
|--------------|-------------------------------------------------|---------------------------------|
| `pg-default` | Docker default, 64MB `/dev/shm`                 | `No space left on device`       |
| `pg-shm`     | `shm_size: 1gb`                                 | Query succeeds                  |
| `pg-mindsm`  | 64MB `/dev/shm` + `min_dynamic_shared_memory=512MB` | Query succeeds              |
| `pg-tight`   | `shm_size: 1gb` + `mem_limit: 256m`             | Backend or parallel worker OOM-killed |

`pg-tight` shows that `/dev/shm` pages are tmpfs memory and count against the
container's memory limit. Raising `shm_size` past the memory limit trades a clean
SQL error for a SIGKILL and a full Postgres restart.

Peak `/dev/shm` use for this query was about 317MB (measured with `df` polling).

## Prerequisites

- Docker Engine with the Compose plugin (tested on Docker 29.9.2)
- About 2GB free RAM
- Tested image: `postgres:18.6`

## Run

```bash
./run.sh
docker compose down -v
```

`results.txt` holds the output from the tested run.
