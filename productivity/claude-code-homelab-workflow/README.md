# claude-code-homelab-workflow

Companion files for the **Claude Code in a Homelab Workflow** article on
[sumguy.com](https://sumguy.com/claude-code-homelab-workflow/).

A drop-in starter pair for pointing [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
at a homelab / self-hosting repo: a `CLAUDE.md` that teaches the agent your conventions,
and a `.claude/settings.json` with a sane permission allowlist, a destructive-command
deny list, and an edit-audit hook.

---

## Files

### `CLAUDE.md`

Project instructions Claude Code reads automatically from the repo root. It describes
the repo layout, your Compose/Bash/Ansible conventions, secret-handling rules, and the
ground rules for the agent (read logs before guessing, validate Compose, ask before
anything destructive). Trim it to match your actual stack.

### `.claude/settings.json`

- **`permissions.allow`** — read-only / inspection commands that run without a prompt
  (`docker compose config`, `docker ps`, `docker logs`, `journalctl`, `systemctl status`,
  `git status/diff/log`, plus `ls`/`cat`/`grep`/`rg`). These are safe, so you stop
  rubber-stamping them.
- **`permissions.deny`** — hard blocks on the stuff you never want an agent to run on
  a box with real data: `rm -rf`, `docker compose down -v`, `docker volume rm`, `dd`,
  `mkfs`, and reads of `.env` / `secrets/`.
- **`hooks.PostToolUse`** — appends a timestamped line to `~/.claude/homelab-edit-audit.log`
  every time the agent edits or writes a file, so you have an audit trail of what it
  touched. Requires `jq` on your `PATH`.

## How to use

```bash
# from your homelab repo root
cp /path/to/CLAUDE.md ./CLAUDE.md
mkdir -p .claude
cp /path/to/.claude/settings.json ./.claude/settings.json

# then just run claude in the repo
claude
```

`.claude/settings.json` is checked into the repo (shared, team-visible settings).
Use `.claude/settings.local.json` for personal overrides you don't want committed —
Claude Code merges it on top and it's gitignored by default.

## Notes

- The allow/deny lists are a starting point, not a security boundary. They reduce
  prompt fatigue and block obvious foot-guns; they are **not** a sandbox. Keep the
  permission prompts on for everything else, and never use
  `--dangerously-skip-permissions` on a box with real data.
- Adjust the allowlist to your stack — if you run Podman, swap the `docker` rules;
  if you use `nerdctl` or `kubectl`, add those.

## Related

- Article: [Claude Code in a Homelab Workflow](https://sumguy.com/claude-code-homelab-workflow/)
- Claude Code docs: <https://docs.anthropic.com/en/docs/claude-code>
