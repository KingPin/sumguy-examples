# Gitea Actions vs Woodpecker CI

Working files for both CI options that sit next to a self-hosted Gitea/Forgejo
instance, so you can stand each one up and compare them side by side.

Article: https://sumguy.com/posts/gitea-actions-vs-woodpecker/

## What's here

```
gitea-actions/
  docker-compose.yml          # act_runner (the Gitea Actions runner)
  .gitea/workflows/ci.yml     # GitHub-Actions-syntax pipeline (Go build/test/lint)
woodpecker/
  docker-compose.yml          # Woodpecker server + agent + Postgres
  .woodpecker.yml             # equivalent Woodpecker pipeline
```

Both pipelines do the same thing — `go mod download`, `go test ./...`,
`go build`, plus a lint step — so you can compare the YAML and the runner
behaviour directly.

## Prerequisites

- A running Gitea **1.21+** (or Forgejo) instance — Actions is server-side here
- Docker + Docker Compose v2
- Tested against: Gitea 1.26, act_runner 0.2.x, Woodpecker 3.x, Postgres 16

## Gitea Actions

1. Enable Actions in Gitea's `app.ini`:
   ```ini
   [actions]
   ENABLED = true
   DEFAULT_ACTIONS_URL = github
   ```
2. Grab a runner registration token: **Site Administration → Actions → Runners**
   (or repo/org level for a scoped runner).
3. Run the runner:
   ```bash
   cd gitea-actions
   RUNNER_TOKEN=xxxxx docker compose up -d
   ```
4. Drop `.gitea/workflows/ci.yml` into a repo and push. Logs and status show up
   inside Gitea's UI.

> Need actions from a host other than github.com? Don't change a config file —
> use an absolute URL in the workflow: `uses: https://gitea.com/actions/checkout@v4`.

## Woodpecker CI

1. Create an OAuth2 app in Gitea: **Settings → Applications → OAuth2 Applications**,
   callback URL `https://ci.example.com/authorize`.
2. Fill the env vars (or use a `.env` file):
   ```bash
   cd woodpecker
   GITEA_OAUTH_CLIENT_ID=... \
   GITEA_OAUTH_CLIENT_SECRET=... \
   AGENT_SECRET=$(openssl rand -hex 32) \
   DB_PASS=$(openssl rand -hex 16) \
   docker compose up -d
   ```
3. Log into the Woodpecker UI (`:8000`), enable your repo, and push. Drop
   `.woodpecker.yml` into the repo root.

Secrets in Woodpecker are set in its own UI and referenced with `from_secret`
inside a step's `environment:` (the old `secrets:` list shorthand was removed in
Woodpecker 2.0).

## Which one?

- **Gitea Actions** — minimal footprint, GitHub Actions syntax + marketplace, no
  extra server. Best when you're already on Gitea/Forgejo and want CI in ~20 min.
- **Woodpecker** — independent server, multi-forge, per-step container isolation,
  branch/event-scoped secrets. Best when CI is a proper first-class service.

Full breakdown in the article linked above.
