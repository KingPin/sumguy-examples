# NetAlertX MCP: One Token, Twelve Tools

A Docker Compose file for [NetAlertX](https://github.com/netalertx/NetAlertX) v26.9.0,
adapted from the project's official compose file to use the published image instead of
a local build, plus the commands to wire its built-in MCP Server Bridge into Claude Code.

This is the working version of the setup from
[NetAlertX MCP: One Token, Twelve Tools](https://sumguy.com/netalertx-mcp-presence-agent/).

## What it does

- Runs NetAlertX with `network_mode: host` (arp-scan needs Layer 2 access), a read-only
  root filesystem, and only the capabilities arp-scan and nmap need.
- Web UI on port `20211`. REST, GraphQL, and the MCP bridge on port `20212`.
- Persists config and the database in one named volume, `netalertx_data`.

## Prerequisites

Tested on:

- Docker Engine 29 with Compose v5.5
- `ghcr.io/netalertx/netalertx:latest` at release v26.9.0 (2026-09-02)
- Claude Code with the `claude mcp add` subcommand
- A Linux host. Windows hosts are not supported because they lack host networking.

## How to run

```bash
docker compose up -d
```

1. Open `http://<host>:20211`, go to Settings, and set `API_TOKEN`. Turn on the web UI
   password too (`SETPWD_enable_password`, `SETPWD_password`). NetAlertX ships with no
   login and a default password of `123456`.
2. Check the API answers:

   ```bash
   curl -s -H "Authorization: Bearer <API_TOKEN>" \
     "http://<host>:20212/devices/by-status?status=online"
   ```

3. Register the MCP bridge in Claude Code:

   ```bash
   claude mcp add --transport sse netalertx http://<host>:20212/mcp/sse \
     --header "Authorization: Bearer <API_TOKEN>"
   claude mcp list
   ```

## Read before you hand out the token

There is one `API_TOKEN` and no scopes. The same token that lets an agent list devices
also lets it call `run_nmap_scan`, `trigger_scan`, `wol_wake_device`, and
`set_device_alias`. If you want a read-only presence feed, route through the MQTT plugin
and Home Assistant's `mcp_server` instead. The article covers both paths.

## Upgrading from an older NetAlertX

v26.9.0 moved custom plugins from `/front/plugins` to `/server/plugins`. If you bind
mount a custom plugin directory, update the container path to
`/app/server/plugins/custom`.
