# Durable Objects: A Per-API-Key Rate Limiter

A minimal Cloudflare Durable Object that rate limits requests per API key, plus a
Worker in front of it that routes each key to its own object instance.

This is the working version of the code from
[Durable Objects: Stateful Serverless](https://sumguy.com/durable-objects-stateful-serverless/).

## What it does

- One Durable Object instance per API key, addressed by name with `getByName()`.
- Each instance keeps its own fixed 60 second window and request count in Durable
  Object storage, so state survives between requests without any external database.
- 30 requests per key per minute. Request 31 gets a `429` with a `Retry-After` header.
- Because a Durable Object is single threaded, the read-modify-write on the counter
  needs no locking and no optimistic-concurrency retry loop. That's the whole reason
  to reach for a DO here instead of KV.

## The bug this example exists to demonstrate

The obvious way to write the window check is wrong:

```ts
// BROKEN: windowStart is never persisted on the first request
const windowStart = (await this.ctx.storage.get<number>("windowStart")) ?? now;
if (now - windowStart > WINDOW_MS) { /* ... */ }
```

Defaulting to `now` means `now - windowStart` is `0` on the first call, so the reset
branch never runs, so `windowStart` never gets written, so it defaults to `now` again
on every later call. The window never starts and therefore never expires. The key
counts to 30 and then returns `429` forever.

`test.sh` catches exactly this: the first five assertions pass with the broken version
and only the window-reset check fails. Persist `windowStart` when it's absent.

## Prerequisites

Tested on:

| Component | Version |
| --- | --- |
| Node.js | 24.18.1 |
| npm | 11.16.0 |
| Wrangler | 4.118.0 |
| `compatibility_date` | 2026-08-01 |

No Cloudflare account or login is needed. `wrangler dev` runs the Durable Object
locally in `workerd`.

## Run it

```bash
npm install
npm run dev
```

Then in another terminal:

```bash
# allowed
curl -i -H "x-api-key: alpha" http://127.0.0.1:8787/

# hammer it past the limit
for i in $(seq 1 31); do
  curl -s -o /dev/null -w "%{http_code}\n" -H "x-api-key: alpha" http://127.0.0.1:8787/
done
```

You should see thirty `200`s and then a `429`.

## Test it

```bash
./test.sh          # full run, includes the 60s window-reset wait
./test.sh --quick  # skips the 60s wait
```

The script starts its own `wrangler dev` on port 8799, waits for it to answer, runs
the assertions, and kills it on exit. It checks: missing key rejected with `401`,
30 requests allowed, 31st limited, a second key unaffected (per-key isolation), the
first key still limited, and recovery after the window expires.

```text
== after the 60s window expires alpha should recover ==
  waiting 62s...
  200, window reset correctly

PASS
```

## Typecheck

```bash
npx wrangler types   # regenerates worker-configuration.d.ts (gitignored)
npm run typecheck
```

## A note on `exports` vs `migrations`

`wrangler.jsonc` declares the Durable Object's lifecycle with the `exports` field:

```jsonc
"exports": {
  "RateLimiter": { "type": "durable-object", "storage": "sqlite" }
}
```

Wrangler 4.118.0 warns if you configure a `durable_objects` binding without a
matching `exports` entry, and it prints that exact block as the fix. The older
`migrations` array is the other way to do it:

```jsonc
"migrations": [
  { "tag": "v1", "new_sqlite_classes": ["RateLimiter"] }
]
```

The two are mutually exclusive. Supply both and Wrangler refuses to load the config
with `` `migrations` and `exports` are mutually exclusive ``. New projects should use
`exports`; existing ones already on `migrations` can stay there.

## Deploying for real

```bash
npx wrangler deploy
```

Durable Objects with SQLite storage are available on the Free plan. Check current
limits and pricing before pointing production traffic at it.
