# Context window math

Companion code for [Context Window Math: Paying to Remember](https://sumguy.com/context-window-math/).

- `context_cost.py` simulates an N-turn chat. Every call re-sends the history, so it prints cumulative input tokens, cost with no caching, cost with prompt caching, and per-turn growth.
- `kv_cache.py` computes KV cache size from layers, KV heads, head dimension, context length, element size, and parallel slots. It can read a HuggingFace `config.json`.

## Prerequisites

Python 3.10 or newer. No dependencies. Tested on Python 3.14.8.

## Run

```bash
python3 context_cost.py --selftest
python3 context_cost.py --turns 200 --in-price 2 --out-price 10 --read-mult 0.05 --write-mult 1.25
python3 kv_cache.py --layers 36 --kv-heads 8 --head-dim 128 --ctx 32768 --slots 4
python3 kv_cache.py --config config.json --ctx 131072
```

Prices and multipliers are arguments. Check your vendor's pricing page before trusting any default.

The cost model assumes every call lands inside the cache TTL and that the prompt only grows at the end. Any edit to earlier history is a cache miss, which you can model by setting `--read-mult` equal to `--write-mult`.
