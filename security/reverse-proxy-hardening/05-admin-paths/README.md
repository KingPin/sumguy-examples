# Reverse proxy hardening, Part 5: admin paths and control planes

The test kit behind [Your Admin Panel Has a Side Door](https://sumguy.com/reverse-proxy-admin-paths/),
a SumGuy's Lab post. It puts nginx, Caddy, and Traefik in front of an Express 5 app with an `/admin` panel,
guards the panel with an IP allow list and forward auth, and then tries to reach it from a stranger's
address with 13 spellings of the same path. It also checks whether a client can forge the identity header
the app trusts, and whether the proxies' own control planes (Traefik's API, Caddy's admin API) answer a
neighbour on the Docker network.

| Mode | Config |
|---|---|
| `baseline` | Where Part 4 stopped: no admin protection at all |
| `trap` | Admin protection the way most guides add it (`trap/`, `compose.trap.yml`) |
| `hardened` | The Part 5 fixes (`hardened/`, `compose.hardened.yml`) |

What the trap configs do:

| Proxy | Trap |
|---|---|
| nginx | `location /admin` with `allow`/`deny` and `auth_request`, plus a `proxy_set_header Remote-User` inside that location |
| Caddy | `@admin path /admin/*` with `client_ip` and `forward_auth`, and `admin 0.0.0.0:2019` so other containers can reach the admin API |
| Traefik | a `PathPrefix(`/admin`)` router with `ipAllowList` and `forwardAuth`, plus the quick-start `--api.insecure=true` next to a "secured" dashboard router |

## What it checks

`probe.sh` runs four groups of tests per proxy:

| Test | Client | Question |
|---|---|---|
| Path variants | `client-out` (stranger), no session | Do `/ADMIN`, `//admin`, `/%61dmin` and 10 other spellings reach the admin panel? |
| Real admin | `client-lan` with a session cookie | Does the fix still let the admin in, and with the right identity? |
| Identity header | both | Can a client send its own `Remote-User` and have the app believe it? |
| Control plane | `client-out` | Does Traefik's API port or Caddy's admin API answer, and can it replace the config? |

"ADMIN PANEL" in the results means the Express admin router answered. The app has no login of its own
(it trusts the proxy), and it reads the user from `Remote-User` the way header-auth setups do.

`auth.py` is a stub shaped like Authelia's verify endpoint: 200 with `Remote-User: alice` for the cookie
`session=alice-ok`, 401 without it, and 200 with no user for paths under `/admin/health` (a bypass rule).
It exists to test how the proxies copy headers. It is not an auth server.

`../audit.sh` then runs against the three proxies to confirm Parts 1 to 4 did not regress. In the
committed hardened run its output matches Part 4's hardened run line for line.

## Prerequisites

- Linux with Docker and Docker Compose v2 (the Caddy image is Part 4's build with mholt/caddy-ratelimit, made
  from `../04-rate-limits/Dockerfile.caddy`; the app image runs `npm install`, so the first build needs network access)
- `curl` and `openssl` on the host
- Free host ports: 8081-8083, 8443, 9443, 10443 (all bound to 127.0.0.1, used by `../audit.sh`), plus 8090 in trap mode
- The subnet 172.31.50.0/24 unused by other Docker networks

Tested with: Docker 29.9.2, nginx 1.31.8, Caddy 2.11.9 with mholt/caddy-ratelimit at commit 5625512f24f6,
Traefik v3.7.17, Node 26.13.0 with Express 5.3.0, python:3.14-alpine, curlimages/curl 8.23.0.

## Run it

```bash
./run.sh            # baseline
./run.sh trap       # admin protection the copy-paste way
./run.sh hardened   # the Part 5 fixes
```

Each mode takes about a minute. Results land in `results-<date>-<mode>/`. The committed results are from
2026-11-07. A second trap run repeated the first one exactly.

## Read this before you run it

- The trap Caddy config publishes nothing extra to the host. The admin API on `0.0.0.0:2019` is reached from
  `client-out` over the lab network, which is what any other container on that network could do.
- The Caddy control-plane test POSTs a replacement config to `/load` and then restarts Caddy. Do not point
  `probe.sh` at a Caddy you care about.
- Express routes case-insensitively by default (`case sensitive routing` is off), which is why `/ADMIN`
  matters here. Your app may differ. The probe tells you which spellings reach your backend.
- Traefik cleans and decodes the path before it forwards it (`//admin` arrives as `/admin`). nginx and Caddy
  forward the path as the client sent it, so Express answered 404 to those spellings in baseline.
- `client-lan` stands in for the admin's LAN or VPN address. Use your own range in `sourceRange`, `allow`,
  and `client_ip`.
- Traefik gets the Docker socket, as in Parts 1 to 4. This stack only routes its own labelled containers.
- The certificates in `certs/` are generated on first run, valid for 30 days, and only for this lab.
