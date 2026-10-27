# A Terminal Built for AI Coding Agents

Companion files for [A Terminal Built for AI Coding Agents](https://sumguy.com/terminal-setup-ai-coding-agents/).

One git worktree per agent, one tmux window per worktree, and a bell that flags the window when the agent is waiting.

## Files

| File | What it does |
| --- | --- |
| `agent-wt` | `new <name> [base-ref]` creates a worktree on branch `agent/<name>` next to the repo and opens a tmux window in it. `rm <name>` removes the worktree, the branch, and the window. `ls` lists worktrees. |
| `tmux.conf` | Scrollback, extended keys, clipboard and passthrough, bell monitoring, mouse. |
| `claude-settings.json` | A Claude Code `Notification` hook that asks Claude Code to emit a BEL via `terminalSequence`. Merge it into `~/.claude/settings.json`. |

## Prerequisites and tested versions

- bash, git, tmux
- Tested on Alpine Linux (edge) in Docker with tmux 3.8 and git 2.56.0
- Claude Code docs checked October 2026 (Claude Code 2.1.311 installed on the author's machine; the hook was not run live in a Claude Code session)
- Optional: any agent CLI. `agent-wt` types `claude` into the new window by default. Set `AGENT_CMD` to use another one, or set it empty for a bare shell.

## How to run

```bash
install -m 755 agent-wt ~/.local/bin/agent-wt
cat tmux.conf >> ~/.tmux.conf    # or copy the lines you want
tmux source-file ~/.tmux.conf

cd ~/code/myapp
tmux                              # agent-wt must run inside tmux
agent-wt new fix-login            # worktree ~/code/myapp-wt/fix-login, branch agent/fix-login
AGENT_CMD=aider agent-wt new docs
agent-wt ls
agent-wt rm fix-login             # refuses if the worktree is dirty; keeps an unmerged branch
```

For the notification hook, merge `claude-settings.json` into `~/.claude/settings.json` (user scope), or into `.claude/settings.json` in a project. Check it with `python3 -m json.tool claude-settings.json`.

## What was tested

In a throwaway repo inside Docker: the config loads without errors, `agent-wt new` creates the worktree and a named window, a second `new` works, a bell printed in a background window sets `window_bell_flag`, a second checkout of the same branch is refused by git, `rm` is refused on a dirty tree, and `rm` on a clean tree removes the worktree, branch, and window.
