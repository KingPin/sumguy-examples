# Reverse proxy hardening, Part 4: rate limits and the real client IP

The test kit behind [Rate Limits That Lock Out the Wrong User](https://sumguy.com/reverse-proxy-rate-limits/),
a SumGuy's Lab post. It puts nginx, Caddy, and Traefik behind a stand-in CDN, adds per-route limits on a
login form and an API, and sends traffic from five clients with their own IP addresses to see who gets
limited: the attacker, or everyone.

| Mode | Config |
|---|---|
| `baseline` | Where Part 3 stopped: no rate limits |
| `trap` | Limits the way most guides add them, keyed on the TCP peer (`trap/`) |
| `trusting` | The trap limits plus a real-IP setup that believes `X-Forwarded-For` from any sender (`trusting/`) |
| `hardened` | The Part 4 fixes (`hardened/`), plus two variants that are each one line off |

The two variants in `hardened` mode:

| Service | What is missing |
|---|---|
| `caddy-nostrict` | `trusted_proxies_strict` (`hardened/Caddyfile.nostrict`) |
| `traefik-notrust` | `--entrypoints.websecure.forwardedHeaders.trustedIPs` |

## What it checks

`probe.sh` runs five tests per proxy and restarts the proxy before each one, so every test starts with
empty rate-limit state.

| Test | Client | Question |
|---|---|---|
| whoami | `client-b` via the CDN | Which client address does the app receive? |
| brute force | `client-a` via the CDN, 20 logins at once; `client-b` tries 3 one second later | Is the attacker limited? Is the bystander? |
| spoof, direct | `client-c` straight to the origin, a new fake `X-Forwarded-For` per request | Can a client that skips the CDN pick its own rate-limit key? |
| spoof, through the CDN | `client-d` via the CDN, a fake entry on the left of `X-Forwarded-For` | Does the proxy read the entry the client wrote or the one the CDN appended? |
| page load | `client-e` via the CDN, 30 API calls at once | How much of a burst gets through, and how long does it wait? |

A request "got through" when the app answered it: 401 for `/login` (the password is always wrong), 200
for `/api/items`. `../audit.sh` then runs against the three main proxies to confirm Parts 1 to 3 did not
regress.

The limits are the same shape on all three: 5 logins per minute per client with room for 5 at once, and
10 API calls per second with room for 20. Each proxy counts differently (nginx's leaky bucket lets the first
request plus the burst through, Caddy's sliding window allows `events` per `window`), so the exact counts
differ by one.

## Prerequisites

- Linux with Docker and Docker Compose v2 (the Caddy image is built locally with `xcaddy`, which needs network access)
- `curl` and `openssl` on the host
- Free host ports: 8081-8083, 8443, 9443, 10443 (all bound to 127.0.0.1, used by `../audit.sh`)
- The subnet 172.31.40.0/24 unused by other Docker networks

Tested with: Docker 29.9.2, nginx 1.31.8, Caddy 2.11.9 with mholt/caddy-ratelimit at commit 5625512f24f6,
Traefik v3.7.17, python:3.14-alpine, curlimages/curl 8.23.0.

## Run it

```bash
./run.sh            # baseline
./run.sh trap       # limits the copy-paste way
./run.sh trusting   # trap limits plus "trust X-Forwarded-For from anyone"
./run.sh hardened   # the Part 4 fixes and the two one-line-off variants
```

`trap` and `trusting` take about five minutes each, because nginx queues delayed logins 12 seconds apart.
Results land in `results-<date>-<mode>/`. The committed results are from 2026-11-06.

## Read this before you run it

- The `Server: nginx/1.31.8` line on responses that went through the CDN is the stand-in CDN's own header,
  not the origin's. The probe drops it from the captured 429 responses.
- nginx and Caddy repeat their counts exactly from run to run. Traefik does not: a second hardened run let
  6 or 7 of 20 logins through where the committed run shows 5, all within 10 ms.
- Stock Caddy has no rate limiter. `Dockerfile.caddy` builds Caddy 2.11.9 with the third-party
  [mholt/caddy-ratelimit](https://github.com/mholt/caddy-ratelimit) module. Stock Caddy rejects the
  config with `unrecognized directive: rate_limit`.
- `172.31.40.10` stands in for your CDN. Behind Cloudflare, trust its published ranges
  (https://www.cloudflare.com/ips/) and read `CF-Connecting-IP` instead.
- Traefik gets the Docker socket, as in Parts 1 to 3. This stack only routes its own labelled backend.
- The certificates in `certs/` are generated on first run, valid for 30 days, and only for this lab.
