# Compose include, extends, and YAML anchors

Runnable examples for the article [Compose include, extends, and YAML Anchors](https://sumguy.com/compose-include-extends-anchors/).
Each folder shows one way to split or dedupe a big Compose file. Every example uses tiny images (`nginx:alpine`, `busybox`, `redis:alpine`).

## Prerequisites

- Docker Engine with Docker Compose v2.20.0 or newer (`include` needs 2.20.0+)
- Tested with Docker Compose v5.6.1

## How to run

Run `docker compose config` first in every folder. It prints the final merged model without starting anything.

| Folder | Technique | Try this |
| --- | --- | --- |
| `01-anchors/` | YAML anchors, merge keys, `x-` fields | `docker compose config`, then `docker compose -f gotcha-sequence.yaml config` (fails on purpose) and `-f multi-merge.yaml config` |
| `02-extends/` | `extends` from another file and the same file | `docker compose config`, `-f same-file.yaml config`, `-f depends.yaml config`, `-f depends-other-file.yaml config` (fails on purpose) |
| `03-include/` | top-level `include:` with a per-project `.env` | `docker compose config`, `-f conflict.yaml config` |
| `04-override/` | `compose.override.yaml`, `-f` merging, `!override`, `!reset` | `docker compose config`, `-f compose.yaml config`, `-f compose.yaml -f reset.yaml config` |

To start a stack and clean up:

```bash
docker compose up -d --wait
docker compose down -v
```

`03-include` writes Redis dump files into `db/data` and `cache/cache-data` as root. Remove them with `docker run --rm -v "$PWD:/w" busybox rm -rf /w/db/data /w/cache/cache-data`.

Published ports used: 8088 (01), 8081 (02), 8082 (03), 8083 (04). Change them if they collide with something on your host.

## What each folder shows

- **01-anchors:** `x-common` holds logging, restart, and healthcheck once. `<<: *common` pulls it into each service. A key set next to the merge replaces the anchored value whole (the `docs` service gets a healthcheck with only `test` and `interval`, no `timeout` or `retries`). `gotcha-sequence.yaml` shows that a merge key cannot pull in a list. `multi-merge.yaml` shows that with `<<: [*a, *b]` the first anchor wins on conflicts.
- **02-extends:** `web` and `worker` extend `shared/common.yaml`. Mappings merge, sequences append, scalars from the child win, and relative paths in the shared file are rebased to the shared file's folder. `depends-other-file.yaml` shows that `depends_on` comes along but the target service does not.
- **03-include:** `db/` and `cache/` are self-contained projects. Each resolves its own relative volume paths and its own env file. The `cache` include passes `env_file` explicitly. `conflict.yaml` shows what Compose v5.6.1 does with a duplicate service name.
- **04-override:** `compose.override.yaml` is read automatically. Passing `-f` turns that off. `reset.yaml` uses `!override` and `!reset`.
