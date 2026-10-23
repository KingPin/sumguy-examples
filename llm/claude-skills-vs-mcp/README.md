# Claude Skills vs MCP: the same chore, both ways

Companion files for [Claude Skills vs MCP: What Each One Is For](https://sumguy.com/claude-skills-vs-mcp/).

Both examples answer one question: "Is my backup directory fresh?" They check the modification time of the newest file under a directory.

- `skill/homelab-backup-check/` is an Agent Skill: a `SKILL.md` plus a small Python script.
- `mcp-server/` is an MCP server (stdio) that exposes the same check as a tool.

## Prerequisites and tested versions

| Piece | Tested with |
| --- | --- |
| Python | 3.14.7 |
| `mcp` Python SDK | 2.3.0 (pinned in `mcp-server/requirements.txt`) |
| Claude Code | 2.1.309 |

The skill script uses only the standard library. The server needs the `mcp` package.

The `mcp` 2.x SDK renamed `FastMCP` to `MCPServer` (`from mcp.server.mcpserver import MCPServer`). Code written for `mcp` 1.x imports `mcp.server.fastmcp` and fails on 2.x. Pin `mcp<2` if you want the old import.

## Install the skill

```bash
mkdir -p ~/.claude/skills
cp -r skill/homelab-backup-check ~/.claude/skills/
```

Run the script by hand first:

```bash
python3 ~/.claude/skills/homelab-backup-check/scripts/check_backups.py /srv/backups --max-age-hours 26
```

Exit code 0 is fresh, 1 is stale, 2 is a bad path.

## Register the MCP server

```bash
python3 -m venv .venv
.venv/bin/pip install -r mcp-server/requirements.txt
claude mcp add --transport stdio backup-check -- "$PWD/.venv/bin/python" "$PWD/mcp-server/server.py"
```

Check it with `claude mcp list`, or `/mcp` inside a session.

## Test the server without Claude

```bash
.venv/bin/python mcp-server/test_client.py
```

Expected output:

```text
tools: ['check_backups']
FRESH: newest file snap.tar is 0.0h old (limit 26h)
```
