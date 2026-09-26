# Prompt Injection vs Your Coding Agent: Capability Limits

Working files for the capability-level defenses in the article. The idea: assume
the agent gets fully hijacked by injected text, and make sure it still can't
reach your secrets or send anything out.

Article: https://sumguy.com/prompt-injection-coding-agents/

## What's here

```
.claude/settings.json   # Claude Code permission rules: deny secrets + curl/wget/push, ask on commit/WebFetch
init-firewall.sh        # default-deny egress with an ipset allowlist (iptables)
compose.yaml            # agent on an internal-only network, egress through a proxy
squid.conf              # the proxy's domain allowlist
```

## Prerequisites

- Claude Code (for `.claude/settings.json`)
- Docker + Docker Compose v2
- For `init-firewall.sh`: root or `--cap-add=NET_ADMIN --cap-add=NET_RAW`, plus
  `iptables`, `ipset`, and `dig` (`dnsutils` / `bind-tools`)
- Tested with: Docker Compose v2, `ubuntu/squid` (latest), `curlimages/curl` (latest)

## How to run it

1. Copy `.claude/settings.json` into your project's `.claude/` directory. Claude
   Code enforces the rules on the next session.
2. Replace `coding-agent:latest` in `compose.yaml` with your own agent image.
   Mount only the workspace. Do not pass cloud credentials or DB strings.
3. Edit the `allowed_sites` line in `squid.conf` for what your task needs.
4. Start it:

   ```bash
   docker compose up -d
   ```

5. Check the allowlist from inside the agent container:

   ```bash
   docker compose exec agent curl -s -o /dev/null -w '%{http_code}\n' https://registry.npmjs.org/   # 200
   docker compose exec agent curl -s -o /dev/null -w '%{http_code}\n' https://example.com/          # refused
   ```

For a single container instead of Compose, run `init-firewall.sh` at container
start. Override the allowlist with `ALLOWED_DOMAINS="registry.npmjs.org github.com"`.
The script resolves domains to IPs once, so re-run it if a CDN rotates addresses.
Two holes remain: outbound DNS (a slow exfil channel) and IPv6, which this
IPv4-only script leaves alone.

## Notes

- `init-firewall.sh` is a simplified version of the mechanism in Anthropic's
  reference devcontainer (`.devcontainer/init-firewall.sh` in
  [anthropics/claude-code](https://github.com/anthropics/claude-code)). Use that
  one if you want GitHub's published IP ranges and the full verification steps.
- `Bash(curl *)` deny rules are pattern matches on the command string. They
  stop the obvious call. The network layer is what stops a creative one.
