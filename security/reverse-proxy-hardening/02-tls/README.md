# Reverse proxy hardening, Part 2: TLS settings

The test kit behind [Reverse Proxy TLS: What the A+ Hides](https://sumguy.com/reverse-proxy-tls-settings/),
a SumGuy's Lab post. It starts nginx, Caddy, and Traefik exactly as Part 1 left them (banner and catch-all
fixes, TLS untouched), checks every TLS setting from the outside, then does it again with the Part 2
fixes and once more with a curve list copied from an older guide.

## What it checks

`tls.sh` is the probe. Point it at any HTTPS endpoint: `./tls.sh 443 your.domain.example 203.0.113.10`.

| Section | Question |
|---|---|
| 1. Protocol versions | TLS 1.0, 1.1, 1.2, 1.3: which ones does the server accept? |
| 2. TLS 1.2 suites | Every suite your OpenSSL knows, one handshake each, tagged no-FS and CBC |
| 3. TLS 1.3 suites | The five TLS 1.3 suites |
| 4. Cipher order | Does the server or the client pick the suite? |
| 5. Key exchange groups | X25519MLKEM768 (post-quantum hybrid), X25519, P-256, P-384, P-521, ffdhe2048 |
| 6. Session resumption | Tickets, server-side session cache, ticket lifetime |
| 7. 0-RTT | Does the server accept TLS 1.3 early data? |
| 8. HSTS | Is `Strict-Transport-Security` sent? |
| 9. Certificate key | Key type and size |

`run.sh` also runs `../audit.sh` (the Part 1 probe, to catch regressions) and testssl.sh 3.2 for its
rating and client simulation.

## Prerequisites

- Linux with Docker and Docker Compose v2
- `curl` and OpenSSL 3.5 or newer on the host (older OpenSSL cannot offer X25519MLKEM768, so section 5 reads "refused" for it)
- Free host ports: 8081-8083, 8443, 9443, 10443 (all bound to 127.0.0.1)
- The Part 1 kit next to this folder: `compose.yml` mounts `../01-default-leaks/backend.py` and the Part 1 hardened configs

Tested with: Docker 29.9.2, nginx 1.31.8 (OpenSSL 3.5.7), Caddy 2.11.7 (Go 1.26.8), Traefik v3.7.17 (Go 1.27.3),
testssl.sh 3.2, curl 8.23.0, OpenSSL 3.6.5 on the host.

## Run it

```bash
./run.sh            # baseline: Part 1 end state, TLS untouched
./run.sh hardened   # Part 2 fixes (compose.hardened.yml + hardened/), plus two nginx -t checks
./run.sh trap       # Part 2 fixes, but each proxy gets an older curve list (compose.trap.yml + trap/)
```

Each run takes about 5 minutes, mostly testssl.sh. Results land in `results-<date>-<mode>/`.
The committed results are from 2026-11-03.

## The Part 2 changes

| | nginx | Caddy | Traefik |
|---|---|---|---|
| TLS 1.2 suites | Mozilla intermediate list (6) | default already matches | Mozilla intermediate list (6) |
| Curves | `X25519MLKEM768:X25519:prime256v1:secp384r1` | default | default (leave `curvePreferences` unset) |
| Resumption | shared session cache, tickets off | default | default |
| HSTS | `add_header ... always` | `header` | `headers.stsSeconds` middleware |

`diff hardened/ trap/` shows the trap: one curve line per proxy.

## Read this before you run it

- The certificates in `certs/` are a throwaway RSA 2048 CA and leaf, generated on first run and valid for 30 days.
  `run.sh` reuses them while `certs/app.crt` exists. After 30 days, run `rm -rf certs` first.
- With an RSA certificate, the three ECDSA suites in the Mozilla list are configured but never offered.
  An ECDSA certificate swaps which three you see.
- Traefik gets the Docker socket, with `exposedbydefault=false`, so it only routes this stack's backend.

## Files

| File | What it is |
|---|---|
| `tls.sh` | The TLS probe |
| `compose.yml` | Baseline stack: Part 1's hardened configs, mounted from `../01-default-leaks/hardened/` |
| `compose.hardened.yml`, `hardened/` | The Part 2 fixes |
| `compose.trap.yml`, `trap/` | Part 2 fixes with an older curve list |
| `run.sh` | Runs everything and writes the results |
