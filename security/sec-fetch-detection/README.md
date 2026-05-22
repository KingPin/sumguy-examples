# sec-fetch-detection

Test harness used in **[Sec-Fetch & UA Client Hints in 2026: What Actually Leaks](https://sumguy.com/posts/sec-fetch-ua-client-hints-2026/)** on SumGuy's Ramblings.

Runs 9 real client tools against a local echo server, captures every request header sent, and aggregates the result into a markdown matrix showing what each tool actually leaks via `Sec-Fetch-*` and `Sec-CH-UA-*` headers.

## What's in here

| Path | What it is |
|---|---|
| `echo-server/server.js` | Tiny Node HTTP server. Returns a 3-resource HTML page (`/style.css`, `/script.js`, `/image.png`) and appends every request's full headers to `results/raw.jsonl`. |
| `native/clients/01-curl.sh` | Plain `curl` baseline. |
| `native/clients/02-python-requests.py` | `requests` library baseline. |
| `native/clients/03-puppeteer-vanilla.js` | Unmodified `puppeteer-core`. |
| `native/clients/04-puppeteer-stealth.js` | `puppeteer-extra` + `puppeteer-extra-plugin-stealth`. |
| `native/clients/05-playwright-vanilla.js` | Unmodified `playwright-core`. |
| `native/clients/06-playwright-stealth.py` | Python Playwright + `playwright-stealth`. |
| `native/clients/07-undetected-chromedriver.py` | Selenium + `undetected-chromedriver`. |
| `native/clients/08-rebrowser.js` | `rebrowser-puppeteer-core` (the rebrowser-patches fork). |
| `native/clients/09-curl-impersonate.sh` | `curl-impersonate-chrome` (TLS + header impersonation). |
| `native/install.sh` | One-time per-package tolerant install (handles Python 3.14 wheel gaps). |
| `native/run.sh` | Boots the echo server, runs all 9 clients, summarizes, kills echo. |
| `aggregate.py` | Reads `results/raw.jsonl`, builds the matrix table at `results/matrix.md`. |
| `NOTES_false_positives.md` | List of legitimate clients that send "bot-shaped" headers. |
| `NOTES_waf_rules_with_bypasses.md` | Caddy / Nginx / Coraza / Cloudflare rules each paired with bypass + mitigation notes. |

## Prerequisites

Tested on Linux (Arch / Cachy, kernel 7.x), but should work on anything with:

- **Node.js 20+** (tested 24.x)
- **Python 3.12+** (tested 3.14, with caveats — Python 3.14 lacks some wheels; `install.sh` is tolerant)
- **A Chromium binary** — the harness reuses an existing one rather than downloading. Set `CHROMIUM_BIN` to point at it. Default looks at the Playwright cache.
- **Optional:** `curl-impersonate-chrome` binary placed at `native/bin/curl_chrome116` (download from the [curl-impersonate releases](https://github.com/lwthiker/curl-impersonate/releases)). Skipped if not present.
- **Optional:** A matching `chromedriver` at `native/bin/chromedriver` for the `undetected-chromedriver` test (it patches the driver in place so it needs a writable copy). Skipped if not present.

## Run it

```bash
cd native
./install.sh                # one-time setup
CHROMIUM_BIN=/path/to/chrome ./run.sh
```

Output:

- `native/results/raw.jsonl` — every request's full headers, one per line
- `native/results/echo.log` — the echo server's stdout

Then aggregate:

```bash
cd ..
python3 aggregate.py native/results/raw.jsonl > native/results/matrix.md
```

## Cleanup

```bash
rm -rf native/.venv native/node_modules native/results
```

No system packages, no Docker, no browser downloads — everything lives under `native/`.

## License

Same as the rest of [sumguy-examples](https://github.com/KingPin/sumguy-examples) — MIT.
