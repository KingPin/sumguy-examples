# Meilisearch vs Typesense: Side-by-Side Example

Working Compose file for both self-hosted search engines, plus a script that indexes
the same 20-movie dataset into each and runs the same typo'd query against both.
Companion to the article:
**[Meilisearch vs Typesense for Self-Hosters](https://sumguy.com/meilisearch-vs-typesense/)**

---

## What's in this folder

| File | What it does |
|------|---------------|
| `docker-compose.yml` | Runs Meilisearch and Typesense side by side |
| `movies.json` | 20 invented movie records (title, director, year, genre, rating) |
| `load_and_query.py` | Indexes `movies.json` into both engines, runs the same typo'd query against each |
| `README.md` | This file |

---

## Prerequisites

- Docker and Docker Compose v2 (`docker compose`, not the old `docker-compose`). Tested with Docker 29.8.0 / Compose 5.5.1.
- Python 3.8 or newer. `load_and_query.py` uses only the standard library, no `pip install` needed.

Image versions pinned in `docker-compose.yml`, verified against the vendors' GitHub releases on 2026-09-23:

- `getmeili/meilisearch:v1.54.0`
- `typesense/typesense:30.2`

## How to run

1. Start both engines:

   ```bash
   docker compose up -d
   ```

2. Wait a few seconds, then confirm both are healthy:

   ```bash
   curl http://localhost:7700/health
   curl http://localhost:8108/health
   ```

3. Index the sample data and run the typo'd query against both:

   ```bash
   python3 load_and_query.py
   ```

   Expected output (both engines return the same movie despite the double typo):

   ```text
   [Meilisearch] query='Forklyft Dreems' processingTimeMs=0
     - Forklift Dreams (2021, Comedy)

   [Typesense] query='Forklyft Dreems' search_time_ms=0
     - Forklift Dreams (2021, Comedy)
   ```

   Timing values vary; a cold first run can show a few milliseconds.

4. Poke around yourself. Meilisearch's search preview UI is at `http://localhost:7700` (only enabled because `MEILI_ENV` is `development`, never expose this in production). Typesense has no bundled UI; query the REST API directly (see the [Typesense API docs](https://typesense.org/docs/)).

5. Tear down:

   ```bash
   docker compose down -v
   ```

## Notes

- Both API keys in `docker-compose.yml` are placeholders (`change-me-master-key`, `change-me-typesense-key`). Replace them before running either engine anywhere reachable off your own machine.
- `load_and_query.py` is idempotent: it recreates the Typesense `movies` collection and re-adds the Meilisearch documents on every run, so you can run it repeatedly while testing.
- Typesense requires the explicit field schema baked into the script (`title`, `director`, `year`, `genre`, `rating`). Meilisearch needs no schema. That contrast is what the companion article compares.
