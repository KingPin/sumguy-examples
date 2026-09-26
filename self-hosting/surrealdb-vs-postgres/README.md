# SurrealDB vs Postgres: Side-by-Side Example

Compose file that runs SurrealDB and PostgreSQL next to each other, plus one script per
database that builds the same small data model (people, a "follows" graph, posts) and
runs the same questions against it: one-hop and two-hop graph queries, a linked-record
lookup, and full-text search.
Companion to the article:
**[SurrealDB vs Postgres: Real or Toy?](https://sumguy.com/surrealdb-vs-postgres/)**

---

## What's in this folder

| File | What it does |
|------|---------------|
| `docker-compose.yml` | Runs SurrealDB (port 8000) and Postgres (port 5432) |
| `surreal.surql` | SurrealQL: SCHEMAFULL tables, RELATE graph edges, record links, FULLTEXT index |
| `postgres.sql` | The Postgres equivalent: join table, recursive CTE, tsvector + GIN index |
| `README.md` | This file |

---

## Prerequisites

- Docker and Docker Compose v2 (`docker compose`). Tested with Docker 29.8.1 / Compose 5.5.1.

Image versions pinned in `docker-compose.yml`, tested on 2026-09-26:

- `surrealdb/surrealdb:v3.2.4`
- `postgres:18-alpine` (PostgreSQL 18.4)

## How to run

1. Start both databases:

   ```bash
   docker compose up -d
   ```

2. Confirm SurrealDB is up:

   ```bash
   curl http://localhost:8000/health
   ```

3. Run the SurrealQL script:

   ```bash
   docker compose exec -T surrealdb /surreal sql --endpoint http://localhost:8000 \
     --user root --pass changeme --ns test --db test --hide-welcome < surreal.surql
   ```

   The two-hop query returns `[{ network: [person:carol] }]` and the record-link query
   returns `{ author: { name: 'Alice' }, title: 'Hello SurrealDB' }`.

4. Run the Postgres script:

   ```bash
   docker compose exec -T postgres psql -U postgres -d sumguy < postgres.sql
   ```

   The recursive CTE returns Bob at depth 1 and Carol at depth 2.

5. Tear down:

   ```bash
   docker compose down -v
   ```

   `./data` and `./pgdata` are bind mounts owned by root. Remove them with
   `sudo rm -rf data pgdata` if you want a clean slate.

## Notes

- Both passwords are `changeme`. Replace them before exposing either port beyond your machine.
- `user: root` on the SurrealDB service is deliberate. The image runs as a non-root user,
  and without it SurrealDB cannot write to the root-owned `./data` bind mount and exits on
  first boot with a permission error.
- Postgres 18 images keep data under a versioned subdirectory, so the volume mounts
  `/var/lib/postgresql`, not `/var/lib/postgresql/data` as older tutorials show.
- The scripts are not idempotent. Run `docker compose down -v` and delete the data
  directories before running them a second time.
