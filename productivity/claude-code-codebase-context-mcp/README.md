# Codebase-context MCP tools for AI coding agents

Representative MCP config for the four tools compared in the article — servers that stop
your agent from dumping the whole repo into context and instead let it read only what matters.

Companion article: **[Stop Feeding the AI Your Whole Repo](https://sumguy.com/claude-code-codebase-context-mcp/)**

## What's here

| File | What it is |
|---|---|
| `mcp.example.json` | Representative Claude Code MCP entries for `code-review-graph`, `token-savior`, and `claude-context` |

**context-mode** isn't in the JSON because it installs as a Claude Code plugin rather than a
hand-written `.mcp.json` entry — follow its own setup. The three above are the ones you'd
typically wire in by hand (or via their installers).

## The important distinctions (why this isn't copy-paste)

- **code-review-graph** — local-first, no keys. Its `install` command auto-detects your agents
  and writes the MCP config for you; the entry here just shows what it configures.
- **token-savior** — local, no cloud keys. The npx form is representative; confirm the current
  package name upstream.
- **claude-context** — **requires a Zilliz Cloud vector DB + an OpenAI embedding API key.**
  The `env` block has placeholders you must fill. This is the one that ships your code's
  embeddings off-box and bills you per index — the local-first dealbreaker from the article.

## Prerequisites

- An MCP-capable agent (Claude Code, Cursor, etc.). Tested notes as of 2026-07.
- `code-review-graph`: Python 3, `pip install code-review-graph` (or `pipx`).
- `claude-context`: a [Zilliz Cloud](https://cloud.zilliz.com) account (free tier) + an OpenAI API key.

## How to run

```bash
# code-review-graph does the wiring for you:
pip install code-review-graph
code-review-graph install     # auto-configures every detected agent
code-review-graph build       # parse your repo into the graph

# for the others, merge the relevant block from mcp.example.json into your
# real .mcp.json, fill in any REPLACE_ME values, and restart your agent.
```

> These are illustrative starting points, not guaranteed-current invocations. Each project's
> README is the source of truth for the exact command — this space moves fast.
