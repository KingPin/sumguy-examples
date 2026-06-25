# Homelab — Claude Code Project Instructions

> Starter `CLAUDE.md` for a homelab / self-hosting repo. Drop it in your repo root,
> trim what doesn't apply, and add the specifics of your stack. The more accurate
> this is, the less you re-explain every session.

## What This Repo Is

This repo holds the configuration for my home lab: Docker Compose stacks for
self-hosted services, a few maintenance scripts, and Ansible playbooks for
provisioning new hosts. Everything here runs on real hardware in my closet —
treat it like production, because to me it is.

## Layout

```
compose/        # one dir per service stack, each with its own docker-compose.yml
scripts/        # bash maintenance + backup scripts
ansible/        # playbooks + roles + inventory
.env.example    # template; real .env files are gitignored and NEVER committed
```

## Conventions

- **Docker Compose:** always pin image tags (no `:latest` in committed files).
  Every long-lived service gets a `restart: unless-stopped` and a `healthcheck`.
  Services that depend on a database use `depends_on: { condition: service_healthy }`,
  not bare `depends_on`.
- **Bash:** every script starts with `set -euo pipefail`. Quote all variable
  expansions. Prefer functions over top-to-bottom scripts once a file passes ~30 lines.
- **Ansible:** prefer modules (`apt`, `copy`, `template`, `lineinfile`) over
  `command`/`shell`. Tasks must be idempotent. Secrets live in `ansible-vault`, never plaintext.
- **Secrets:** never read, print, or commit `.env`, `*.env`, or anything under
  `secrets/`. If a task seems to need a secret value, ask — don't guess or echo it.

## Ground Rules for the Agent

- Show me the plan before making sweeping multi-file changes.
- When debugging a service, read the actual logs (`docker logs`, `journalctl`,
  `systemctl status`) before proposing a fix — don't guess from the symptom.
- Validate Compose changes with `docker compose config` before telling me they're done.
- Do **not** run anything destructive (volume deletes, `rm -rf`, `down -v`) without
  asking first, even if it looks obviously correct. See `.claude/settings.json` —
  the deny list backs this up, but you should respect the intent regardless.
