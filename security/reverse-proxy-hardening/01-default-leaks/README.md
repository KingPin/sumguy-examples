# Reverse proxy hardening, Part 1: what the default config leaks

The test kit behind [What Your Reverse Proxy Leaks by Default](https://sumguy.com/reverse-proxy-default-leaks/),
a SumGuy's Lab post. It starts nginx, Caddy, Traefik, and Nginx Proxy Manager with the minimal
config each project's docs give you, puts one deliberately leaky app behind them, and probes
everything from the outside the way a scanner would.

## What it checks

| Probe | Question |
|---|---|
| HTTP and HTTPS headers | Does the proxy (or the app behind it) announce software and versions? |
| Bare IP on port 80 | What does a scanner that only knows your IP get? |
| TLS with no SNI / unknown SNI | Which certificate (and which hostnames) does the proxy hand a stranger? |
| Spoofed `X-Forwarded-For` | Does the app see the client's real IP, or whatever the client claims? |
| `/boom` and app-down | Do stack traces and proxy error pages leak versions? |
| Admin surfaces | Traefik dashboard API, Caddy admin API, NPM admin port 81 |
| First-run traps | Traefik quick-start auto-routing, NPM's unclaimed admin account |
| testssl.sh | Protocols, cipher suites, rating |

`../audit.sh` is the outside-in probe. Later parts of the series reuse it.

## Prerequisites

- Linux with Docker and Docker Compose v2
- `curl`, `openssl`, `python3` on the host
- Free host ports: 8081-8085, 8090, 8181, 8443, 9443, 10443, 11443 (all bound to 127.0.0.1)

Tested with: Docker 29.9.2, nginx 1.31.8, Caddy 2.11.7, Traefik v3.7.17, Nginx Proxy Manager 2.16.0,
testssl.sh 3.2, python:3.14-alpine, curl 8.23.0, OpenSSL 3.6.5.

## Run it

```bash
./run.sh            # stock configs: every probe plus three testssl.sh scans, about 6 minutes
./run.sh hardened   # the Part 1 fixes (compose.hardened.yml + hardened/), same probes, no scans
```

Results land in `results-<date>/` and `results-<date>-hardened/`. The committed results are from 2026-11-02.

## Read this before you run it

- Traefik gets the Docker socket, like its quick start. Its dashboard then lists **every container on
  your machine**, not just this stack. `run.sh` prints this stack's services by name and reduces the
  rest to a count and a port list, so the results files do not leak your other projects.
- The first-run probe creates an admin account on the throwaway NPM container. `run.sh` deletes the
  container and its volumes at the end.
- The certificates in `certs/` are generated on first run, valid for 30 days, and only for this lab.
  `run.sh` reuses them while `certs/app.crt` exists, so after 30 days run `rm -rf certs` first or the
  testssl.sh results change.

## Files

| File | What it is |
|---|---|
| `compose.yml` | Stock stack: backend, nginx, Caddy, Traefik (quick-start flags plus an HTTPS redirect), NPM |
| `backend.py` | The leaky app: `X-Powered-By`, Python's `Server` banner, a stack trace on `/boom`, header echo on `/` |
| `nginx/app.conf`, `caddy/Caddyfile`, `traefik/dynamic.yml` | Minimal stock proxy configs |
| `compose.hardened.yml`, `hardened/` | The Part 1 fixes |
| `run.sh` | Runs everything and writes the results |
