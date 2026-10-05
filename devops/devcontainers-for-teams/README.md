# Devcontainers for a whole team

A small Python app that talks to Postgres, wired up as a team devcontainer: `devcontainer.json` + Docker Compose, a pinned Dev Container Feature, lifecycle hooks, a prebuilt image, and a CI workflow that runs the tests inside the same container.

Companion to https://sumguy.com/devcontainers-for-teams/

## Layout

```text
app.py                         tiny psycopg app (notes table)
tests/test_app.py              one test against the real Postgres service
requirements.txt               pinned Python deps
.env.example                   copy to .env (gitignored)
.devcontainer/
  devcontainer.json            Compose-based config, Feature pin, lifecycle hooks
  compose.yaml                 app + Postgres (with a healthcheck)
  Dockerfile                   base image + pip install baked in
  devcontainer-lock.json       resolved Feature digest (generated, commit it)
.github/workflows/devcontainer-ci.yml   test in the container, then build + push
```

## Prerequisites

- Docker Engine with the Compose plugin
- Node.js (only to run the devcontainer CLI via `npx`)

Tested with Docker 29.8.x, Docker Compose 5.5.1, `@devcontainers/cli` 0.89.0, on Linux x86_64.
The GitHub Actions workflow was not run end to end; it is a template. Replace `your-org` with your own registry namespace.

## Run it

```bash
cp .env.example .env   # optional; defaults match
npx -y @devcontainers/cli@0.89.0 up --workspace-folder .
npx -y @devcontainers/cli@0.89.0 exec --workspace-folder . python -m pytest -q
```

Build the image the way CI does (no push):

```bash
npx -y @devcontainers/cli@0.89.0 build --workspace-folder . --image-name devcontainers-for-teams:test
docker inspect devcontainers-for-teams:test --format '{{index .Config.Labels "devcontainer.metadata"}}'
```

Clean up:

```bash
docker compose -p devcontainers-for-teams_devcontainer down -v
docker rmi devcontainers-for-teams:test
```

In VS Code, run "Dev Containers: Reopen in Container" instead of the `up` command.

## Notes

- `devcontainer build --push` and `--platform` are rejected for Compose configs in 0.89.0 (`--platform or --push not supported`). The workflow publish job builds with `--frozen-lockfile`, then runs `docker push`. The `devcontainers/ci` action can also push Compose images itself via its `push: filter` input.
- Lifecycle hooks do not run during `devcontainer build`, so Python dependencies are installed in the Dockerfile, not in a hook.
- The Postgres service has a healthcheck, and `app` waits for it with `condition: service_healthy`. Without it, `postCreateCommand` races the database.
