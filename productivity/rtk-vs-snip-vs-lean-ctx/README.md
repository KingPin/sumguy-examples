# Token-killer proxies: RTK vs snip vs lean-ctx

Working config for the "token-killer" proxy comparison — tools that sit between your
AI coding agent and the model and filter command output *before* it burns context tokens.

Companion article: **[RTK vs snip vs lean-ctx: Token Killers](https://sumguy.com/posts/rtk-vs-snip-vs-lean-ctx/)**

## What's here

| File | What it is |
|---|---|
| `snip.toml` | snip config showing the ordered `filters.dir` array (global + per-repo override) |
| `filters/git-log.yml` | Declarative snip filter — condenses `git log` to hash + one-line message, `on_error: passthrough` |
| `filters/git-status.yml` | Declarative snip filter — collapses `git status` to short porcelain |

These are [snip](https://github.com/edouard-claude/snip) filters — the "binary is the engine,
filters are data" design. RTK and lean-ctx don't use portable filter files (RTK bakes its
behavior in; lean-ctx is a broader platform), so this folder focuses on the one tool whose
config is worth version-controlling.

## Prerequisites

- **snip** — Go binary. Tested against snip as of 2026-07. See the [repo](https://github.com/edouard-claude/snip) for install.
- A snip-supported agent. For **Claude Code**, snip installs a native PreToolUse hook.

## How to run

```bash
# 1. install snip (see upstream repo), then wire it into Claude Code:
snip init

# 2. drop the config + filters where snip looks for them:
mkdir -p ~/.config/snip/filters
cp snip.toml   ~/.config/snip/config.toml
cp filters/*.yml ~/.config/snip/filters/

# 3. (optional) per-repo overrides live in ./.snip/ inside a project;
#    a filter there with the same name wins over the global one.

# 4. sanity check — run a git log through the agent and watch it come back condensed.
```

## The one honest caveat

`on_error: passthrough` is the important line in every filter. It means a filter that
fails hands back the *original* output instead of silently returning nothing. That's the
behavior that separates a safe proxy from one that quietly eats your data — the exact
footgun the article calls out with RTK's swallowed `sed -i` edits.
