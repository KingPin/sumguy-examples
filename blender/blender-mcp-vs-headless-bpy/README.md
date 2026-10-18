# Blender MCP vs headless bpy

A minimal headless Blender build kit, plus a config for the live Blender MCP server. Companion to [Blender MCP vs Headless bpy Scripts](https://sumguy.com/blender-mcp-vs-headless-bpy/).

## What it does

- `build.py` builds two low-poly props (a crate and a buoy), assigns flat role materials, exports one GLB, asserts a triangle budget per prop, re-imports the GLB to confirm names and materials survived, and optionally renders a preview PNG with EEVEE.
- `check_glb.py` reads the GLB JSON chunk with the Python standard library, prints triangles per mesh, and exits 1 if any mesh is over budget.
- `mcp.json.example` registers the official Blender Lab `blender_mcp` server for MCP clients that read a JSON config.

## Prerequisites

- Blender 5.2.2 LTS on your `PATH` (tested version)
- Python 3 for `check_glb.py` (stdlib only)
- For the MCP config only: `uv`, a checkout of `blender_mcp` 1.0.2, and its add-on enabled in a running Blender (listens on localhost port 9876)

## Run

```bash
blender -b --python-exit-code 1 --python build.py -- --norender   # no preview
blender -b --python-exit-code 1 --python build.py                 # also writes out/preview.png
python3 check_glb.py out/props.glb --budget 120
```

Output lands in `out/`. A budget breach in `build.py` or `check_glb.py` exits non-zero, so CI or a loop of agents can gate on it.

Claude Code registration for the MCP server:

```bash
claude mcp add blender -- uv --directory /path/to/blender_mcp/mcp run blender-mcp
```
