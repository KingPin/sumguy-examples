# LLM semantic caching

A hand-rolled semantic cache, a script that scores real embedding similarities (paraphrases vs dangerous near-misses), and a LiteLLM + Redis 8 setup with the `redis-semantic` cache type.

- `semantic_cache.py`: the cache. Pluggable `embed` function, cosine similarity threshold, TTL, namespace keyed on model + system prompt hash. Stdlib only.
- `test_semantic_cache.py`: assert-based self-check with a fake bag-of-words embedder (hit, near-miss, namespace isolation, TTL).
- `score_pairs.py`: prints cosine similarity for 11 query pairs with two real embedding models. Output is in `results.txt`.
- `redisvl_demo.py`: RedisVL `SemanticCache` with a local fastembed vectorizer. Output is in `redisvl_output.txt`.
- `litellm-config.yaml` + `compose.yaml` + `embed_stub.py`: LiteLLM proxy with `redis-semantic` caching, Redis 8, and a stub embedding server. Output of the request test is in `litellm_test.txt`.

Write-up: https://sumguy.com/llm-semantic-caching/

## Prerequisites and tested versions

- Python 3.14 for `semantic_cache.py` and its test (stdlib only)
- `uv` for the scripts that need packages
- fastembed 0.9.1 (`BAAI/bge-small-en-v1.5`, `sentence-transformers/all-MiniLM-L6-v2`, downloaded on first run)
- redisvl 0.30.0
- Redis 8 image (`redis:8`, server 8.10.3 when tested, bundled search module 8.10.1)
- LiteLLM proxy image `ghcr.io/berriai/litellm:main-stable` (the exact version inside the image was not recorded; PyPI latest on the test day was 1.108.0)
- Docker with Compose

## Run

```bash
python3 test_semantic_cache.py

uv run --with fastembed --with numpy python score_pairs.py

docker run -d --name sc-redis -p 6391:6379 redis:8
uv run --with redisvl==0.30.0 --with fastembed python redisvl_demo.py
docker rm -f sc-redis

docker compose up -d
curl -i localhost:4000/v1/chat/completions \
  -H 'Content-Type: application/json' -H 'Authorization: Bearer sk-local-test-key' \
  -d '{"model":"docs-bot","messages":[{"role":"user","content":"How do I restart nginx?"}]}'
docker compose down -v
```

Send the same curl twice. The second response carries `x-litellm-cache-key` and the same `id` as the first.

## What was actually tested

- `test_semantic_cache.py`: run, passes.
- `score_pairs.py`: run for real with both models. The numbers in the article come from `results.txt`.
- `redisvl_demo.py`: run against `redis:8`. A paraphrase hit at distance 0.051 and the "stop nginx" near-miss was a miss at `distance_threshold=0.10`.
- LiteLLM stack: started, and the cache path confirmed. An identical second request returned the same response `id`, an `x-litellm-cache-key` header, and `x-litellm-semantic-similarity: 0.9999999403953552`. That is a cache hit.
- NOT tested: a real chat model and a real embedding model behind LiteLLM. The chat model is a LiteLLM `mock_response` and the embedder is `embed_stub.py` (hashed bag of words, wiring only). With the stub, the paraphrase "What is the command to restart nginx" correctly missed because the stub is not semantic. Do not read threshold behavior from `litellm_test.txt`. Use `results.txt` for that.
- NOT tested: `qdrant-semantic`, `valkey-semantic`, TTL behavior inside LiteLLM, multi-worker setups.

## Notes

- The LiteLLM image refused to start without a master key, so `compose.yaml` sets a throwaway `LITELLM_MASTER_KEY`. Change it for anything real.
- The `redis-semantic` cache type failed at boot with `Missing required Redis configuration: REDIS_PASSWORD` until `redis_url` was set under `cache_params`. The config sets it from `REDIS_URL`.
- LiteLLM uses a similarity threshold (higher is stricter). RedisVL uses a distance threshold (lower is stricter), `distance = 1 - cosine similarity` here.
