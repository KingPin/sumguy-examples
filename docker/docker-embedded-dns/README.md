# Docker embedded DNS demo

Companion files for [Docker's Embedded DNS: Inside 127.0.0.11](https://sumguy.com/docker-embedded-dns/).

## What it does

Starts four services on three networks so you can poke at the embedded resolver at `127.0.0.11`:

- `web` (scaled to 3 replicas, `hostname: webhost`) and `api` (`container_name: demo-api`, alias `backend`) share the `front` network.
- `other` sits alone on `back`, so `front` containers cannot resolve it.
- `lone` sits on an `internal: true` network, so external lookups fail.

## Prerequisites

- Docker Engine with Compose v2. Tested on Docker 29.8.2.

## Run

```bash
docker compose up -d --scale web=3
docker exec demo-api cat /etc/resolv.conf
docker exec demo-api nslookup web 127.0.0.11      # three A records
docker exec demo-api nslookup backend 127.0.0.11  # alias
docker exec demo-api nslookup other 127.0.0.11    # NXDOMAIN (other network)
docker exec <project>-lone-1 nslookup example.com 127.0.0.11   # SERVFAIL (internal network)
docker compose down
```

Replace `<project>` with your Compose project name (the directory name by default). Passing `127.0.0.11` to `nslookup` explicitly avoids search-domain noise from your host's `resolv.conf`.

Full walkthrough: https://sumguy.com/docker-embedded-dns/
