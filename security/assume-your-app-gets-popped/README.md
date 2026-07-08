# Assume Your App Gets Popped — Defense-in-Depth for a Public Box

Working files for the layered hardening described in the article: how to expose
a possibly-vulnerable app (a public adblocking DNS resolver, in this case) to the
open internet and contain the damage when — not if — something gets poked.

Article: https://sumguy.com/posts/assume-your-app-gets-popped/

## What's here

```
compose.yaml            # rootless AdGuard Home — cap_drop ALL, read_only, no-new-privileges
aide.conf               # file-integrity tripwire config (Layer 2)
reverse-tunnel.service  # autossh + systemd reverse tunnel — NO inbound SSH (Layer 3)
```

## The three layers

1. **Rootless container, unprivileged user** (`compose.yaml`) — a container escape
   lands the attacker as an ownerless, sudo-less user, not root on the host.
2. **File-integrity tripwire** (`aide.conf`) — a cryptographic snapshot of every
   file that shouldn't change; a schedule check screams the moment one does.
3. **No inbound SSH** (`reverse-tunnel.service`) — the box dials *out* to a bastion
   and you ride the reverse tunnel back in. Nothing to scan on port 22, because
   nothing is listening.

## Prerequisites

- Docker + Docker Compose v2, **running rootless** (see the article's links)
- A dedicated, shell-less, sudo-less service user (e.g. `dns-svc`) to own the stack
- `aide` installed on the host
- `autossh` + OpenSSH on the box, and a separate **bastion** host you control
- Tested against: AdGuard Home (latest), AIDE 0.18.x, autossh 1.4g, OpenSSH 9.x

## How to run it

### Layer 1 — the rootless resolver

```bash
# as the dns-svc user, with rootless Docker already set up
docker compose up -d
```

Firewall the `3000/tcp` admin UI to a management VLAN — do not expose it publicly.

### Layer 2 — the tripwire

```bash
sudo cp aide.conf /etc/aide/aide.conf
sudo aide --init
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db   # promote the baseline
```

Then schedule the check (cron or, better, a systemd timer) and pipe any non-empty
diff to something that actually pages you:

```text
0 */2 * * * /usr/sbin/aide --check | mail -s "AIDE report: $(hostname)" you@yourdomain.com
```

Re-run `aide --init` and promote the DB after every *intentional* change (package
updates, config edits) so the baseline stays current.

### Layer 3 — the reverse tunnel (no inbound SSH)

On the **public box**:

```bash
# generate a key that will ONLY be allowed to open this one forward
sudo -u tunnel-svc ssh-keygen -t ed25519 -f /home/tunnel-svc/.ssh/id_ed25519_bastion -N ""

sudo cp reverse-tunnel.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now reverse-tunnel.service
```

On the **bastion**, lock the key down in `tunnel-svc`'s `authorized_keys` so a
stolen key can do nothing but open this tunnel. Note it's `permitlisten` (which
governs reverse `-R` forwards), **not** `permitopen` (which governs outbound `-L`
forwards) — a common and dangerous mix-up:

```text
restrict,permitlisten="127.0.0.1:22022" ssh-ed25519 AAAA... tunnel-svc@public-box
```

`restrict` disables everything (pty, agent/X11 forwarding, all port forwarding);
`permitlisten` re-enables exactly one thing — binding that single loopback port.

To get in, SSH into the bastion (hardened separately), then hop the loopback port:

```bash
ssh -p 22022 admin@localhost
```

## Notes

- Edit `bastion.example.net`, the key path, ports, and usernames to match your setup.
- Port `443` on the outbound tunnel is deliberate — it blends into normal HTTPS
  egress and survives restrictive outbound firewalls.
- None of this makes the box unhackable. It shrinks the blast radius, makes an
  intrusion loud, and removes the SSH attack surface entirely. "Nobody got in that
  I could tell" is the honest goal.
