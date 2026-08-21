# claude-code-multi-account

Companion files for the **Multiple Claude Code Accounts, One Config** article on
[sumguy.com](https://sumguy.com/claude-code-multi-account-config/).

Run several [Claude Code](https://docs.anthropic.com/en/docs/claude-code) accounts on
one Linux box, at the same time, in the same repo, sharing every skill, agent, hook,
plugin and transcript between them. Only the login is isolated.

The whole trick is that Claude Code reads its config from one directory, and almost
nothing in that directory is actually about *who you are*. Point `CLAUDE_CONFIG_DIR`
somewhere else, symlink the tooling back, and keep the few files that hold account
state as real per-profile files.

---

## Files

### `link-profiles.sh`

Builds and repairs the alternate profile directories. Edit the `PROFILES` array at the
top to name yours, then run it.

```bash
./link-profiles.sh --dry-run   # show what would change
./link-profiles.sh             # apply
```

Safe to re-run. It replaces only symlinks, skips anything missing from your primary
config rather than creating it, and refuses to overwrite a real file or directory it
did not create.

### `aliases.sh`

The shell aliases, plus a small `claude-whoami` helper that prints which account the
current pane is authenticated as. Append to `~/.zshrc` or `~/.bashrc`.

```bash
alias claude-alt-1="CLAUDE_CONFIG_DIR=$HOME/.claude-alt-1 claude"
alias claude-alt-2="CLAUDE_CONFIG_DIR=$HOME/.claude-alt-2 claude"
```

Your primary account keeps the plain `claude` command and `~/.claude`.

---

## What is shared and what is not

| Path | Side | Why |
| --- | --- | --- |
| `settings.json`, `settings.local.json` | shared | Model, theme, permissions, hooks, enabled plugins. Symlinked, so `/config` from any profile writes through to the primary. |
| `CLAUDE.md` | shared | Your global instructions. |
| `skills/`, `agents/`, `commands/`, `plugins/`, `hooks/`, `scripts/` | shared | Pure tooling. This is why every skill and plugin behaves identically in all profiles. |
| `projects/`, `sessions/`, `history.jsonl` | shared | Transcripts and prompt history. Any account can pick up where another left off. |
| `cache/`, `paste-cache/`, `file-history/`, `backups/` | shared | Working state that is not identity. |
| `.credentials.json` | **isolated** | The OAuth token. About 500 bytes. This file *is* the account. |
| `.claude.json` | **isolated** | 40 to 50 KB per profile: project registry, folder-trust state, onboarding flags, user-scoped MCP servers, account metadata. |
| `security/`, `session-env/`, `shell-snapshots/` | **isolated** | Per-session and per-account runtime state. |
| `policy-limits.json`, `remote-settings.json` | **isolated** | Server-pushed, per-account. |

## Gotchas

- **Plugins and skills carry over. `claude mcp add` servers do not.** Enabled plugins
  live in the shared `settings.json`, so they work everywhere. MCP servers you add with
  `claude mcp add` are written to the root of `.claude.json`, which is per-profile. Add
  them again in each profile.
- **Project `.mcp.json` approvals reset per profile.** Trust state lives in
  `.claude.json` too, so a repo you already approved on your main account prompts again
  on an alternate.
- **Do not use a blanket "delete everything non-hidden" cleanup step.** It is tempting,
  and it is wrong: `security/`, `session-env/`, `shell-snapshots/`,
  `policy-limits.json` and `remote-settings.json` are all *non-hidden* per-account
  state. A wipe that keys off `! -name '.*'` protects `.credentials.json` and
  `.claude.json` and blows away the rest. `link-profiles.sh` relinks in place instead.
- **Never symlink the source directories into existence.** A script that runs
  `mkdir -p "$PRIMARY/$folder"` before linking will fill your primary config with empty
  directories Claude Code never uses. This one skips what is absent and says so.
- **`history.jsonl` has multiple writers.** All profiles append to the same file. Three
  concurrent sessions, exited and restarted, produced no corruption in testing, but the
  sample is small. This is the first thing to unlink if prompt history starts looking
  strange.
- **Authenticate with the emailed verification code, not Google SSO.** Browser SSO tends
  to silently reuse whatever account the browser is already signed into, which leaves
  you with two profiles logged in as the same person.

## Getting invites to land in one inbox

If the accounts are seats in a Google Workspace org, plus-addressing
(`you+alt1@yourdomain.com`) is unreliable. Free aliases work better:

Google Admin Console > Directory > Users > pick the account > **Alternate Email
Addresses (Aliases)**. Add `cc-alt1@yourdomain.com`, send the seat invitations there,
and they arrive in the primary inbox.

## Notes

- Each profile needs its own seat. This shares *configuration*, not entitlement.
- Tested on Linux. Works on Windows too, where credentials live at
  `%USERPROFILE%\.claude\.credentials.json`. It does NOT isolate identity on
  macOS: credentials there are stored in the encrypted Keychain, which
  `CLAUDE_CONFIG_DIR` does not scope, so every profile authenticates as the same
  account. The tooling symlinks still work on macOS; the account separation does not.
- `CLAUDE_CONFIG_DIR` is read at startup, so a running session keeps the directory it
  launched with. Switching accounts means opening a new pane, not re-exporting the
  variable.

## Related

- Article: [Multiple Claude Code Accounts, One Config](https://sumguy.com/claude-code-multi-account-config/)
- Claude Code docs: <https://docs.anthropic.com/en/docs/claude-code>
