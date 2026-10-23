"""Minimal MCP server exposing a backup freshness check (mcp 2.x SDK)."""
import time
from pathlib import Path

from mcp.server.mcpserver import MCPServer

mcp = MCPServer("homelab-backup-check")


@mcp.tool()
def check_backups(directory: str, max_age_hours: float = 26.0) -> str:
    """Report whether the newest file under `directory` is newer than max_age_hours."""
    root = Path(directory)
    if not root.is_dir():
        return f"ERROR: {root} is not a directory"
    newest = max(
        (p for p in root.rglob("*") if p.is_file()),
        key=lambda p: p.stat().st_mtime,
        default=None,
    )
    if newest is None:
        return f"STALE: {root} contains no files"
    age = (time.time() - newest.stat().st_mtime) / 3600
    state = "FRESH" if age <= max_age_hours else "STALE"
    return f"{state}: newest file {newest.name} is {age:.1f}h old (limit {max_age_hours:g}h)"


if __name__ == "__main__":
    mcp.run()  # stdio by default
