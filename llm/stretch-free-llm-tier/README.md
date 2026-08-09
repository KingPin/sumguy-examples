# Stretching a Free LLM Tier

Working files for the habits that make a free tier last: prompt caching that
actually hits, batching without losing the batch, backoff that treats a 429 as
routine, and a router that rotates a pool of free providers so a rate limit on
one of them never reaches your application.

The free tier usually dies from what you feed it, not from a stingy quota. These
are the four pieces with code behind them.

Full write-up: <https://sumguy.com/stretch-free-llm-tier/>

## What's here

| File | What it is |
|------|------------|
| `cacheable_prompt.py` | A prompt split so the static half sits in front of an Anthropic `cache_control` breakpoint and the changing half sits after it. Prints the cache-creation and cache-read token counts so you can confirm the cache is engaging. |
| `STYLE_GUIDE.md` | The static half. A real review style guide, sized to clear the cache minimum (see the gotcha below). |
| `batch_classify.py` | Classifies many short strings in one call instead of one call per string, validates the structured reply against the input, and falls back to per-item calls only for a batch that failed. |
| `retry_with_backoff.py` | Exponential backoff with jitter, honouring `Retry-After` when the provider sends one. |
| `litellm-config.yaml` | A LiteLLM proxy config putting several free tiers in one rotating pool behind a single OpenAI-compatible endpoint, with a paid model as the fallback. |

## Prerequisites

- Python 3.9+
- `pip install anthropic` for the three scripts, `pip install 'litellm[proxy]'`
  for the config
- `ANTHROPIC_API_KEY` in the environment. The scripts name `claude-sonnet-5`;
  substitute any model you have access to.

The LiteLLM config additionally expects `OPENROUTER_API_KEY_1` and
`GEMINI_API_KEY`. Drop any pool entry whose key you do not have; a pool of one
still works, it just has nothing to rotate to.

## How to run it

**Prompt caching.** Run it twice inside five minutes against the same diff. The
first call reports a large `cache creation` number and a zero `cache read`; the
second reports the reverse. If both stay at zero, the breakpoint is not
engaging, and the gotcha below is almost always why.

```bash
git diff > /tmp/change.diff
python3 cacheable_prompt.py /tmp/change.diff
python3 cacheable_prompt.py /tmp/change.diff   # cache read should be non-zero
```

**Batching.**

```bash
python3 batch_classify.py                # built-in sample of 8 log lines
python3 batch_classify.py /var/log/mylog # one line per input line
```

Eight lines go out as one call rather than eight. A malformed reply, a dropped
item, or an invented category all fail validation and drop that batch to
per-item retries rather than silently returning garbage.

**Backoff.**

```bash
python3 retry_with_backoff.py "summarize this in one sentence: ..."
```

**The router.**

```bash
litellm --config litellm-config.yaml --port 4000

curl http://localhost:4000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model": "free-workhorse", "messages": [{"role": "user", "content": "hi"}]}'
```

Ask for `free-workhorse` and you never find out which backend served the
request. LiteLLM parks a deployment for `cooldown_time` seconds once it has
failed `allowed_fails` times, routes to a healthy entry in the pool, and only
escalates to `paid-overseer` when the whole free pool is unavailable.

## The gotcha that wastes an afternoon

**A cached block below the provider's minimum is silently ignored.** Anthropic
will not cache a prefix shorter than 1,024 tokens on Sonnet and Opus, or 2,048
on Haiku. You get no error, no warning, and no cache: the call just costs full
price and you are left wondering whether you wrote the breakpoint wrong.

`STYLE_GUIDE.md` here is roughly 1,400 tokens for exactly that reason. An
earlier, shorter draft came in around 950 and cached nothing at all. If you swap
in your own and the cache read counter stays at zero, check the length before
you check anything else.

The other way to get zero cache hits is to let dynamic content into the static
block. A timestamp, a request ID, a "today's date" string, or a branch name
anywhere in front of the breakpoint invalidates the cache on every single call.
Keep dynamic content after the marker, without exception.

## Tested versions

- `anthropic` 0.89.0. `cache_control: {"type": "ephemeral"}` on a `system`
  block, and `usage.cache_creation_input_tokens` / `usage.cache_read_input_tokens`
  on the response, are current for this version.
- The `Retry-After` read is `exc.response.headers.get("retry-after")`. Verified
  against `anthropic._exceptions.APIStatusError.__init__`, which assigns
  `self.response` (an `httpx.Response`). There is **no** `exc.retry_after`
  attribute, so the common `getattr(exc, "retry_after", None)` version of this
  snippet always returns `None` and makes the whole branch unreachable.
- Backoff and batch-validation logic exercised end to end against mocked
  clients: `Retry-After` honoured, exponential fallback when the header is
  absent, re-raise on exhaustion, and all three batch failure modes (short
  reply, unknown category, non-JSON) degrading to per-item retries.
- LiteLLM `router_settings` keys used here (`fallbacks`, `num_retries`,
  `retry_after`, `cooldown_time`, `allowed_fails`) parse as valid YAML and match
  the documented router options.

## A note on rotating accounts

The pool in `litellm-config.yaml` rotates across *providers*. Rotating several
free accounts at the *same* provider is a different thing, and some providers
explicitly forbid it. Read the terms before you automate your way around a rate
limit. Getting banned everywhere at once is a worse outcome than waiting twenty
minutes.
