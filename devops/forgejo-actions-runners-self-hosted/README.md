# Forgejo Actions: Self-Hosted CI with Forgejo Runner

Working files for running GitHub-Actions-style CI on your own Forgejo server.

Article: https://sumguy.com/forgejo-actions-runners-self-hosted/

## What's here

```
docker-compose.yml            # dind + runner, for a Forgejo you already run
setup.sh                      # prepares ./data and seeds data/config.yml
config.yml.example            # annotated runner config: labels, cache, container
ci-runner.Dockerfile          # job image with BOTH node and the docker CLI
full-stack/
  docker-compose.yml          # Forgejo 16 + dind + runner, from nothing
  setup.sh                    # generates the shared secret and UUID
.forgejo/workflows/build.yml  # node build + test + docker image, with caching
```

## Prerequisites

- Docker and Docker Compose v2
- A Forgejo instance you administer (or use `full-stack/` to get one)
- Tested against: Forgejo 16.0.3, Forgejo Runner 13.0.0, host Docker 29.6.2,
  dind server 29.7.2, Compose v5.3.1 (2026-08-28)

The `full-stack/` compose was booted end to end for this: runner registered and
went Idle, a workflow with `actions/checkout@v6` ran, `secrets.FORGEJO_TOKEN`
and `secrets.GITHUB_TOKEN` both resolved, and a `docker build` step produced and
ran an image against the dind daemon.

## Why Docker-in-Docker and not the host socket

Plenty of guides mount `/var/run/docker.sock` into the runner. That does not
work with the official image: it runs as uid 1000 and is not a member of the
host `docker` group, so the daemon gets permission denied on the socket. Adding
the runner to the docker group fixes the error and hands the runner
root-equivalent access to the host, which is a bad trade for a process that
executes code from your repositories.

The dind sidecar keeps job containers in their own daemon. The runner reaches
it over TLS on `tcp://docker:2376` with certs from a shared volume.

Two config keys make that work, and both are easy to miss:

- `container.network: host` puts job containers in the dind container's network
  namespace, which is on the compose network. Without it they land on dind's own
  bridge, the Forgejo service name does not resolve, and `actions/checkout` hangs
  for 4.5 minutes per `git fetch` attempt before the job dies.
- `runner.envs` carries `DOCKER_HOST` / `DOCKER_TLS_VERIFY` / `DOCKER_CERT_PATH`
  into jobs. There is no `container.envs` key in Runner 13.

On first boot the runner exits a few times with
`could not read CA certificate "/certs/client/ca.pem"` because dind has not
finished writing certs yet. `restart: unless-stopped` rides it out; it settled
after four restarts over three seconds in testing.

## Runner on an existing Forgejo

1. Prepare the data directory and config:

   ```bash
   ./setup.sh
   ```

2. In Forgejo, create a runner and copy its UUID and Token. Pick the scope you
   want:

   | Scope | Path |
   | --- | --- |
   | Whole instance | `/admin/actions/runners` |
   | Organization | `/org/{org}/settings/actions/runners` |
   | User | `/user/settings/actions/runners` |
   | Single repository | `/{owner}/{repo}/settings/actions/runners` |

   Click **Create new runner**, then copy the UUID and Token from the dialog.

3. Put them in `data/config.yml` under `server.connections`:

   ```yaml
   server:
     connections:
       forgejo:
         url: https://git.example.com/
         uuid: 33834eef-e758-48c4-a676-1745426747aa
         token: d4fe2db46a4c6bdc434a9ce3378d9a1489c1b30e
   ```

4. Start it:

   ```bash
   docker compose up -d
   docker compose logs -f runner
   ```

The runner appears as **Idle** on the same Runners page.

## From-scratch stack

```bash
cd full-stack/
./setup.sh
# follow the printed steps
```

This uses offline registration: `setup.sh` generates a 40-character secret,
derives the UUID from its first 16 characters, and you register that secret with
`forgejo forgejo-cli actions register`. It needs admin access to the Forgejo
server, so it is not an option on a hosted instance like Codeberg.

## Labels

Labels decide which jobs a runner accepts and what image each job runs in. They
live in `runner.labels` in the runner config file, not in the Forgejo web UI and
not on a registration command line.

```
<label-name>:<label-type>://<image>
```

`label-type` is `docker`, `lxc`, or `host`. A workflow's `runs-on:` value has to
match a `label-name`.

```yaml
runner:
  labels:
    - ubuntu-latest:docker://data.forgejo.org/oci/node:22-bookworm
    - node22:docker://docker.io/library/node:22-alpine
    - arm64:docker://docker.io/library/node:22-bookworm?platform=linux/arm64
```

Architecture is a query string on the image, not a second label.

Listing more than one label in a job's `runs-on:` array requires a runner that
declares **all** of them, which is how you route to the box with the GPU:

```yaml
jobs:
  train:
    runs-on: [docker, gpu]
```

`host` type runs steps straight on the runner with no isolation. A single job
can destroy the machine. Only use it on a runner you would happily rebuild.

### The label image is the job environment

JS actions (`actions/checkout`, `actions/setup-node`) are executed with `node`
inside the job container. `docker build` steps need the docker CLI. No stock
image ships both:

| Image | node | docker CLI | Fails with |
| --- | --- | --- | --- |
| `oci/node:22-bookworm` | yes | no | `docker: command not found` |
| `oci/docker:cli` | no | yes | `exec: "node": executable file not found in $PATH` |

For a job that checks out code and builds an image, build your own from
`ci-runner.Dockerfile` and point a label at it.

## Caching

`actions/cache` works. The runner runs its own cache server and passes
`ACTIONS_CACHE_URL` into job containers, so nothing is sent to Forgejo.

```yaml
cache:
  enabled: true
  dir: ""              # empty = $HOME/.cache/actcache, which is under /data here
  external_server: ""  # point several runners at one server to share cache
  secret: ""           # required if you set external_server
  host: ""             # set when job containers are on another network
```

`host` is the hostname used to build `ACTIONS_CACHE_URL`. It is not the address
of an external cache server. That field is `external_server`.

## Workflow files

Put workflows in `.forgejo/workflows/`. Forgejo falls back to
`.github/workflows/` when `.forgejo/workflows/` is absent, so an imported GitHub
repository runs with no rename.

Tokens are aliased, so GitHub-shaped workflows keep working:

| GitHub | Forgejo |
| --- | --- |
| `secrets.GITHUB_TOKEN` | `secrets.FORGEJO_TOKEN` |
| `github.token` | `forgejo.token` |
| `env.GITHUB_TOKEN` | `env.FORGEJO_TOKEN` |

Known differences that bite:

- `permissions:` and `continue-on-error:` on a job are ignored.
- Some keys in the `github` context are missing.
- `actions/upload-artifact` and `download-artifact` need v3, or a patched v4.
- Actions resolve against `DEFAULT_ACTIONS_URL`, which defaults to
  `https://data.forgejo.org`, not github.com.

## Server settings worth knowing

Actions is enabled by default. You only touch `app.ini` to turn it off:

```ini
[actions]
ENABLED = false
```

Job logs are written to disk by the Forgejo server, under `actions_log/`. Move
them with the `[storage.actions_log]` section, not with a key in `[actions]`.
Retention is what you usually want to change:

```ini
[actions]
LOG_RETENTION_DAYS = 365
ARTIFACT_RETENTION_DAYS = 90
LOG_COMPRESSION = zstd
```

## Teardown

```bash
docker compose down -v
sudo rm -rf data/
```
