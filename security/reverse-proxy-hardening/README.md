# Reverse proxy hardening (series)

Kits for the SumGuy's Ramblings series on hardening nginx, Caddy, and Traefik.

| Part | Topic | Kit |
|---|---|---|
| 1 | [What the default config leaks](https://sumguy.com/reverse-proxy-default-leaks/) | [`01-default-leaks/`](01-default-leaks/) |
| 2 | [TLS settings](https://sumguy.com/reverse-proxy-tls-settings/) | [`02-tls/`](02-tls/) |
| 3 | [Security headers](https://sumguy.com/reverse-proxy-security-headers/) | [`03-headers/`](03-headers/) |

`audit.sh` is the shared outside-in probe: `./audit.sh HTTP_PORT HTTPS_PORT [HOSTNAME] [ADDR]`.
Point it at your own proxy to see what a stranger sees. It needs only `curl` and `openssl`.
`02-tls/tls.sh` is the TLS probe: `./02-tls/tls.sh HTTPS_PORT [HOSTNAME] [ADDR]`.
`03-headers/headers.sh` counts the security headers on five kinds of response: `./03-headers/headers.sh HTTPS_PORT [HOSTNAME] [ADDR]`.
