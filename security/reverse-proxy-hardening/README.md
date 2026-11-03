# Reverse proxy hardening (series)

Kits for the SumGuy's Ramblings series on hardening nginx, Caddy, and Traefik.

| Part | Topic | Kit |
|---|---|---|
| 1 | [What the default config leaks](https://sumguy.com/reverse-proxy-default-leaks/) | [`01-default-leaks/`](01-default-leaks/) |

`audit.sh` is the shared outside-in probe: `./audit.sh HTTP_PORT HTTPS_PORT [HOSTNAME] [ADDR]`.
Point it at your own proxy to see what a stranger sees. It needs only `curl` and `openssl`.
