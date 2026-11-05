# Reverse proxy hardening, Part 3: security headers

The test kit behind [Reverse Proxy Security Headers](https://sumguy.com/reverse-proxy-security-headers/),
a SumGuy's Lab post. It puts nginx, Caddy, and Traefik in front of one app and checks two things for each
of three configs: which security headers reach the client on every kind of response, and what a real
Chromium does with them.

| Mode | Config |
|---|---|
| `baseline` | Where Part 2 stopped: banners stripped, TLS hardened, HSTS the only security header |
| `trap` | Seven headers added the way most guides add them (`trap/`) |
| `hardened` | The Part 3 fixes (`hardened/`) |

## What it checks

| Probe | Question |
|---|---|
| `headers.sh` | Which security headers arrive on `/`, `/app`, `/static/a.css`, a 404, and a 500, and how many copies of each? |
| `app-raw-<proxy>.txt` | `/app`'s headers in wire order: when a header arrives twice, which copy comes last? |
| `browser.py` framing | Can the app frame its own pages? Can a stranger's site frame them? |
| `browser.py` referrer | When a user leaves `/app` (which sets `Referrer-Policy: no-referrer`) for another site, what does that site learn? |
| `../audit.sh` | The series' outside-in probe, to confirm nothing from Parts 1 and 2 regressed |

The app (`backend.py`) has a route for each case a proxy has to handle: a plain page with no headers of
its own, a page that sets its own framing, CSP, and referrer policy (like apps that ship their own security headers), an older
page that sets only `X-Frame-Options: SAMEORIGIN`, a static file, a 404, and a 500.

## Prerequisites

- Linux with Docker and Docker Compose v2
- `curl`, `openssl`, `python3` on the host
- Python Playwright: `pip install playwright && playwright install chromium`, or point `CHROMIUM` at a system Chromium
- Free host ports: 8081-8083, 8443, 9443, 10443 (all bound to 127.0.0.1)

Tested with: Docker 29.9.2, nginx 1.31.8, Caddy 2.11.7, Traefik v3.7.17, python:3.14-alpine,
Playwright 1.58.0 with Chromium 156, curl 8.23.0.

## Run it

```bash
./run.sh            # baseline
./run.sh trap       # headers the copy-paste way
./run.sh hardened   # the Part 3 fixes
CHROMIUM=/usr/bin/chromium ./run.sh hardened   # use a system browser
```

Each run takes about a minute. Results land in `results-<date>-<mode>/`. The committed results are from 2026-11-05.

## Read this before you run it

- Traefik gets the Docker socket, as in Parts 1 and 2. This stack only routes its own labelled backend.
- `hardened/nginx-app.conf` uses `add_header_inherit merge`, which needs nginx 1.29.3 or later. On older
  nginx, move the server-level `add_header` lines into a snippet and `include` it in every location that
  adds a header of its own.
- The Traefik hardened overlay gives `/app` and `/legacy` their own router, because one backend plays
  two apps here. In real life that split is one router per app.
- The certificates in `certs/` are generated on first run, valid for 30 days, and only for this lab.
