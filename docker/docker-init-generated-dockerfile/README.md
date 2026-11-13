# docker init: what it generates, and what to fix

Companion kit for the SumGuy's Ramblings post
[docker init: Fix These Before You Ship](https://sumguy.com/docker-init-generated-dockerfile/).

Three tiny apps (Python/Flask + gunicorn, Node/Express, Go) were run through
`docker init` with every default accepted. The files it wrote are kept as
`*.generated*`. Next to them sit the fixed versions, and `measure.sh` builds
both and compares them.

## Layout

```
python/  app.py, requirements.txt
node/    server.js, package.json, package-lock.json
go/      go.mod, cmd/server/main.go

<lang>/Dockerfile.generated              docker init output, untouched
<lang>/Dockerfile.generated.dockerignore docker init .dockerignore, untouched
<lang>/compose.generated.yaml            docker init compose.yaml, untouched
<lang>/Dockerfile                        fixed
<lang>/.dockerignore                     fixed (also catches .env.*)
<lang>/compose.yaml                      fixed (restart policy + healthcheck)
node/Dockerfile.execonly                 exec-form CMD only, no tini (shows why tini is needed)
README.Docker.md.generated-python        the README docker init writes
results.txt                              raw output of two measure.sh runs
```

BuildKit picks up `<Dockerfile>.dockerignore` next to the Dockerfile, so
`docker build -f Dockerfile.generated` uses the generated ignore file and
`docker build` (default `Dockerfile`) uses the fixed `.dockerignore`.

## Prerequisites

- Docker Engine with BuildKit (tested: Engine 29.9.2, buildx v0.29.1, Linux).
- `curl`, `awk`, bash 4+.
- `docker init` itself is only needed if you want to regenerate the files. It
  ships with Docker Desktop (tested plugin: Docker Init v1.4.1, from Docker
  Desktop 4.99.0). `measure.sh` does not need it.

## Run

```bash
./measure.sh
```

For each app and variant it prints: BuildKit check warnings, image size,
whether a planted `.env.production` ends up in the image, the PID 1 command,
how long `docker stop` takes, and the exit code. A stop time of about 10 s with
exit 137 means the process ignored SIGTERM and Docker killed it.

It plants `.env.production` in each app dir during the run and deletes it on exit.

## What the numbers show (2026-11-13)

| app | variant | check warnings | .env.production in image | docker stop |
|---|---|---|---|---|
| python | generated | 2 | yes | 10.1 s, exit 137 |
| python | fixed | 0 | no | 0.2 s |
| node | generated | 2 | yes | 0.6 s, exit 1 |
| node | execonly | 0 | no | 10.2 s, exit 137 |
| node | fixed (tini) | 0 | no | 0.3 s |
| go | generated | 0 | no | 0.1 s |

Full output in `results.txt`.
