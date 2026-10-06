# nginx vs Caddy: benchmark kit

The test kit behind [nginx vs Caddy: Measured](https://sumguy.com/nginx-vs-caddy-benchmark/), a SumGuy's Lab post.
It runs nginx and Caddy with near-stock configs on one machine, pins each part of the test
to its own CPU cores, and measures throughput, latency, CPU, and memory.

## What it tests

| Scenario | What it measures |
|---|---|
| `static-http` / `static-https` | 1 KB file, keep-alive, HTTP/1.1 |
| `big-http` / `big-https` | 100 KB incompressible file |
| `newconn-https` | New TLS connection per request (handshake cost) |
| `proxy-https` | HTTPS reverse proxy to a small backend (`traefik/whoami`) |
| `proxy-fixed` | Same proxy at a fixed 5,000 req/s, for latency |
| `proxy-sustained` | Same proxy at full load for 90 s, once per config, with TIME_WAIT counts every 20 s. Skip with `SUSTAINED=0` |

Server configs (pick with `SERVERS=`; default `nginx nginx-upstream caddy caddy-keepalive`):

| Config | What it is |
|---|---|
| `nginx` | Near stock. `proxy_pass http://whoami:80/` straight to the backend hostname |
| `nginx-upstream` | Same, but the backend sits in an `upstream` block (keepalive is on by default there since nginx 1.29.7). Proxy tests only |
| `nginx-keepalive` | Upstream block plus `keepalive 32`, `proxy_http_version 1.1`, empty `Connection` header. Needed on nginx older than 1.29.7. Proxy tests only |
| `caddy` | Near stock Caddy (32 idle backend connections per host, the default) |
| `caddy-keepalive` | Caddy with `keepalive_idle_conns_per_host 128`. Proxy tests only |

Access logs are off on both servers. Every test starts fresh containers, so TIME_WAIT
sockets from one test cannot starve the next of local ports.

## Prerequisites

- Linux with Docker, cgroup v2 (`/sys/fs/cgroup/system.slice/docker-<id>.scope` must exist), and root. The script reads container cgroup files and `/proc/<pid>/net/tcp`.
- Python 3
- At least 8 CPU threads. Check `lscpu -e=CPU,CORE` and set the pinning variables to match your CPU.

Tested with: Docker 29.8, Ubuntu 22.04 (kernel 6.8), nginx 1.31.6 and 1.28.3, Caddy 2.11.6, oha 1.16.0, traefik/whoami 1.11.0.

## Run it

```bash
./bench.sh            # 20 s per test, 3 runs each, plus 90 s sustained tests (about 45 minutes)
SUSTAINED=0 ./bench.sh 5 1   # quick smoke test
python3 summarize.py  # median tables in Markdown
```

Override CPU pinning for your machine:

```bash
SERVER_CPUS=0,1 LOADGEN_CPUS=2-5 BACKEND_CPUS=6,7 ./bench.sh
```

Repeat the older-nginx proxy tests:

```bash
NGINX_IMAGE=nginx:1.28.3-alpine SERVERS="nginx nginx-upstream nginx-keepalive" OUT=results-1.28 ./bench.sh
```

Record the bare `proxy_pass` failure over time (start `bench-whoami` and a `bench-server`
running `configs/nginx.conf` the way `bench.sh` does, then):

```bash
mkdir -m 777 timeline
docker run --rm --network benchnet -v "$PWD/timeline:/out" ghcr.io/hatoo/oha:1.16.0 \
  --no-tui --insecure -z 120s -c 100 -q 1000 --db-url /out/nginx.db https://bench.lab/proxy/
```

`summarize.py` counts only 2xx responses as successful. oha's own `requestsPerSec`
includes 502s, which hides the bare `proxy_pass` failure.

Keep the server's hyperthread siblings idle, or the load generator shares a physical core
with the server. Stop other busy containers on the box before you run it.

## Files

- `configs/`: the five server configs above
- `bench.sh`: runs every scenario, writes JSON to `results/`
- `summarize.py`: prints median tables (`python3 summarize.py <results dir>`)
- `results-2026-10-05/`: raw results for nginx 1.31.6 and Caddy 2.11.6 used in the post
- `results-2026-10-05-nginx-1.28/`: raw results for nginx 1.28.3
- `results-2026-10-05-timeline/timeline-10s.csv`: 120 s at a steady 1,000 req/s through a bare
  `proxy_pass`, successes and 502s per 10 seconds (captured with `oha --db-url`)
