# Migrate bookmarks to a self-hosted tool

Merges Chrome, Firefox, Raindrop, Pocket, and Pinboard exports into one deduplicated Netscape HTML file, triages dead links, and imports into linkding.

Post: https://sumguy.com/migrate-bookmarks-self-hosted/

## Files

| File | Purpose |
|------|---------|
| `normalize.py` | Parses every export, dedups with linkding's URL rules, writes one flat HTML file |
| `linkcheck.py` | Checks each URL and writes a CSV report (`ok`, `moved`, `gone`, `error`, `blocked`) |
| `tag_dead_links.py` | Tags `gone` bookmarks in linkding through the REST API. Deletes nothing |
| `test_normalize.py` | Assert-based test over `samples/` |
| `samples/` | Small synthetic exports, one per source |

## Prerequisites

Python 3.11 or newer. No dependencies. Tested with Python 3.14.7 (as of October 2026) against linkding v1.47.0 behavior.

## Run

```bash
# 1. Merge (drop --folder-tags to skip folder-to-tag mapping)
python3 normalize.py --folder-tags --out merged.html /path/to/exports/*

# 2. Test
python3 test_normalize.py

# 3. Triage dead links (add --wayback to look up snapshots, 1.5 s per lookup)
python3 linkcheck.py merged.html --out report.csv --workers 16 --timeout 10

# 4. Import with the management command
docker cp merged.html linkding:/tmp/merged.html
docker compose exec linkding python manage.py import_netscape /tmp/merged.html you

# 5. Tag dead links (optional)
LINKDING_URL=https://linkding.example.lan LINKDING_TOKEN=your-token python3 tag_dead_links.py report.csv
```
