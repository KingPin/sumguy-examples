# Cheap Workhorse Model: Overseer + Workhorse Pattern

Config for the **overseer/workhorse** pattern in Claude Code: an expensive
"overseer" model (Sonnet/Opus) scopes and reviews work, while a cheap or free
"workhorse" model does the mechanical grunt work (refactors, boilerplate,
renames, format conversions). You save tokens two ways — cheaper per-token
execution, *and* the workhorse's churn stays out of the overseer's context.

Full write-up: <https://sumguy.com/cheap-workhorse-model-ai-coding/>

For the **local, self-hosted** workhorse (Ollama / llama.cpp in Docker, with a
tested delegation script), see the companion example
[`local-workhorse-ollama-docker-claude`](../local-workhorse-ollama-docker-claude/)
and article <https://sumguy.com/local-workhorse-ollama-docker-claude/>.

## What's here

| File | Goes in | What it is |
|------|---------|------------|
| `workhorse.md` | `.claude/agents/` | A subagent definition pinned to a cheap model (`claude-haiku-4-5`). The overseer dispatches atomic tasks to it; it runs in its own context window. |
| `delegate.md` | `.claude/commands/` | A `/delegate` slash command for the shell-out variant — the overseer calls an external cheap-model CLI and then reviews the result. |

## How to use it

1. Copy `workhorse.md` into your project's (or `~/.claude/`) `agents/` directory.
2. Copy `delegate.md` into the matching `commands/` directory if you want the
   shell-out variant.
3. In a Claude Code session, let the overseer hand mechanical tasks to the
   `workhorse` subagent, or run `/delegate` for the CLI variant.

## The two non-negotiables

- **Scope tightly.** Cheap models are great at well-specified mechanical work
  and bad at ambiguity. Remove every shred of ambiguity before handing off.
- **Always review the output.** The overseer reads the diff before accepting.
  A workhorse that silently breaks something is worse than no workhorse.

## Swapping the workhorse model

Keep the worker model as a single config value. To switch from Haiku to a local
model, a free-tier cloud model, or whatever's cheapest this quarter, change one
line — don't hard-couple to a model whose pricing will inevitably change.
