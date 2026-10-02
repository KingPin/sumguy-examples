# Clef vs Jev: same decision, two hosted APIs

Companion code for [Clef vs Jev: Cloudflare's 4x Tie](https://sumguy.com/clef-vs-jev/).

Sends one `state` plus one typed `choice` question to three hosted decision
models and prints each answer, confidence, and token count:

- **Jev** (TypeSafe) through OpenRouter's alpha decisions route
- **Clef** and **Clef-flash** (Cloudflare) through Workers AI

`slash-key-repro.sh` reproduces a Workers AI compatibility gap: a `choice`
question is rejected with HTTP 400 (code 5006) when every option key contains
a `/`. Jev accepts the same request.

## Prerequisites

- `bash`, `curl`, `jq`
- For Jev: an OpenRouter API key with access to `~typesafe/jev-latest`
- For Clef: a Cloudflare account ID and an API token with Workers AI permission
- Tested 2026-10-01 against `typesafe/jev-1.13-20260917`, `@cf/cloudflare/clef`,
  and `@cf/cloudflare/clef-flash`

Either provider can be skipped: the script only calls the ones whose
credentials are set.

## Run

```bash
export JEV_API_KEY=sk-or-...            # optional
export CLOUDFLARE_ACCOUNT_ID=...        # optional
export CLOUDFLARE_API_TOKEN=...         # optional

./ask.sh "handle empty response from the weather API"
./ask.sh "your own state text" my-questions.json

./slash-key-repro.sh
```

Expected repro output (as of October 2026):

```text
== all keys contain a slash
HTTP 400
[{"message":"AiError: Bad input: Error: required properties at '/' are 'model,state,questions' (...)","code":5006}]
== one key without a slash
HTTP 200
== workaround: dotted keys
HTTP 200
```

The workaround is to swap `/` for `.` in the keys and keep the real path in
the description text.

## Cost

Workers AI usage counts against a free allocation of 10,000 neurons per day.
Each `ask.sh` call uses a few hundred input tokens per model, so a handful of
runs costs nothing on either side.
