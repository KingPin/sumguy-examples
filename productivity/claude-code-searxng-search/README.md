# claude-code-searxng-search

Companion files for the **Claude Code + SearXNG: Private Web Search** article
on [sumguy.com](https://sumguy.com/claude-code-searxng-search/).

A tiny Bash wrapper that turns a self-hosted [SearXNG](https://github.com/searxng/searxng)
instance into a web-search command your AI coding agent (Claude Code, Aider, whatever
shells out to a terminal) can call. Private queries, no per-query API cost, full control
over engines and result count — a complement to Claude Code's built-in `WebSearch` tool,
not a wholesale replacement.

---

## Files

### `websearch`

The wrapper itself. Drop it on your `PATH` (e.g. `~/.claude/bin/websearch`, or
anywhere else on PATH like `~/.local/bin/`) and `chmod +x` it. It hits SearXNG's JSON
API and prints ranked, numbered results (title / URL / snippet) — or raw JSON with
`--json` for piping into `jq`.

```bash
chmod +x websearch
mkdir -p ~/.claude/bin
cp websearch ~/.claude/bin/        # or anywhere on PATH

# point it at your instance (or rely on the localhost:8383 default)
export SEARXNG_URL="http://localhost:8383"

websearch "rootless podman vs docker 2025" 5
websearch -c news -t week "kubernetes cve"
websearch -e brave,duckduckgo "zfs arc tuning"
websearch --json "caddy reverse proxy" 3 | jq '.results[].url'
```

| Flag | Meaning |
|---|---|
| `-n, --num N` | number of results (default 10; positional 2nd arg also works) |
| `-c, --category` | `general,images,news,videos,music,files,science,it,map` |
| `-e, --engine` | comma-separated engine list (e.g. `brave,duckduckgo`) |
| `-t, --time` | `day,week,month,year` |
| `-l, --lang` | language code (`en`, `en-US`, `de`, …) |
| `-s, --safe` | safe search: `0` off, `1` moderate, `2` strict |
| `-j, --json` | raw JSON passthrough |

Env: `SEARXNG_URL` (default `http://localhost:8383`), `WEBSEARCH_TIMEOUT` (default `15`).

User input is passed to the embedded Python as **environment variables, never
interpolated into the source** — so quotes, `$`, and shell metacharacters in a query
can't break out. Safe to point an autonomous agent at.

### `docker-compose.yml`

Minimal SearXNG + Redis stack. Publishes host port `8383` (matching the wrapper's
default). See the header comment for the one-time config-generation step.

### `searxng-settings-snippet.yml`

The settings that matter. **The wrapper will not work until `json` is added to
`search.formats`** — SearXNG serves HTML only by default and returns HTTP 403 to JSON
requests. Also covers a sane engine list (Brave/DDG/Mojeek on, Google off) and the
limiter trade-off for a private instance.

---

## Quick start

```bash
# 1. generate default config
mkdir -p searxng
docker run --rm -v "$(pwd)/searxng:/etc/searxng" \
  searxng/searxng:latest \
  sh -c "cp /usr/local/searxng/searx/settings.yml /etc/searxng/settings.yml"

# 2. edit searxng/settings.yml — add `json` to search.formats, set a secret_key
#    (see searxng-settings-snippet.yml)

# 3. bring it up
docker compose up -d

# 4. verify the JSON API answers
curl -s 'http://localhost:8383/search?q=test&format=json' | head

# 5. install + use the wrapper
chmod +x websearch && mkdir -p ~/.claude/bin && cp websearch ~/.claude/bin/
websearch "it works" 3
```

---

## Prerequisites

- **Docker** + Compose v2 (`docker compose`, not `docker-compose`)
- **Python 3** on the machine running the wrapper (stdlib only — no `pip install`)
- Network reachability from the wrapper host to the SearXNG instance (LAN, `localhost`,
  Tailscale, or a reverse-proxied domain — set `SEARXNG_URL` accordingly)

Tested with SearXNG `latest` (2026), Docker 27.x, Python 3.11.

---

## Related

- Article: [Claude Code + SearXNG: Private Web Search](https://sumguy.com/claude-code-searxng-search/)
- [SearXNG docs](https://docs.searxng.org/)
- [SearXNG search API](https://docs.searxng.org/dev/search_api.html)
