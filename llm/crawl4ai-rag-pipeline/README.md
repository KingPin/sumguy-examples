# Crawl4AI to Qdrant: a local RAG ingest pipeline

Crawls a docs site with Crawl4AI, chunks the fit-markdown by heading, embeds the chunks with `nomic-embed-text` through Ollama, stores them in Qdrant, and answers queries with `query_points`.

Companion code for the SumGuy's Ramblings post [Crawl4AI: Feed Your RAG From the Web](https://sumguy.com/crawl4ai-rag-pipeline/).

## Files

- `compose.yaml`: Qdrant, Ollama, and an optional Crawl4AI REST server (`api` profile)
- `crawl.py`: deep crawl, fit markdown to `pages/`
- `ingest.py`: chunk, embed, upsert
- `query.py`: embed a question, print the top 3 hits

## Prerequisites and tested versions

- Docker with Compose
- Python 3.10+ (tested on 3.14)
- crawl4ai 0.9.4, qdrant-client 1.19.1, httpx 0.28
- Qdrant v1.19.1, Ollama (latest image), model `nomic-embed-text` (768 dimensions)

## Run

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install crawl4ai qdrant-client httpx
crawl4ai-setup                      # installs the Playwright browser

docker compose up -d qdrant ollama
docker compose exec ollama ollama pull nomic-embed-text

python crawl.py https://docs.example.com/ 50   # start URL, max pages
python ingest.py
python query.py "How do I configure rate limits?"
```

`crawl.py` honors robots.txt, runs 2 pages at a time with a 1 to 2 second delay, and caches pages locally, so a second run does not re-fetch them. Change the `user_agent` string to something that identifies you.

## Optional: REST API instead of the Python library

```bash
export CRAWL4AI_API_TOKEN="$(openssl rand -hex 32)"
docker compose --profile api up -d crawl4ai
curl -s http://localhost:11235/md \
  -H "Authorization: Bearer $CRAWL4AI_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://docs.example.com/", "f": "fit"}'
```

## Notes

- Point IDs are `uuid5(url#chunk_index)`, so re-ingesting overwrites instead of duplicating. If a page shrinks, old trailing chunks stay until you delete them.
- If you change the embedding model, change `size=` in `ingest.py` and recreate the collection. Dimensions must match.
