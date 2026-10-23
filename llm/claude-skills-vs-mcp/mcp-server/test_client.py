"""Spawn server.py over stdio, list tools, call one. Run: python test_client.py"""
import asyncio
import sys
import tempfile
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


async def main() -> None:
    params = StdioServerParameters(command=sys.executable, args=[str(Path(__file__).with_name("server.py"))])
    with tempfile.TemporaryDirectory() as d:
        (Path(d) / "snap.tar").write_text("x")
        async with stdio_client(params) as (r, w):
            async with ClientSession(r, w) as s:
                await s.initialize()
                tools = await s.list_tools()
                print("tools:", [t.name for t in tools.tools])
                res = await s.call_tool("check_backups", {"directory": d})
                print(res.content[0].text)


asyncio.run(main())
