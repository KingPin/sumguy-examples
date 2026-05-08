# Garage + Nextcloud (MinIO Replacement)

A working Docker Compose stack that runs Nextcloud with all file data living in [Garage](https://garagehq.deuxfleurs.fr/) — an S3-compatible object store designed for small self-hosted deployments. This is the recommended replacement after MinIO archived its open-source community edition on April 25, 2026.

📖 **Full article:** [MinIO Is Archived: Move to Garage](https://sumguy.com/minio-archived-garage-alternative/)

## What This Is

A four-service Compose stack:

- **garage** — single-node Garage instance, S3 API on `:3900`, admin API on `:3903`
- **nextcloud** — Apache image, talks to Garage as its primary object store
- **db** — Postgres 16 for Nextcloud's metadata
- **redis** — file locking / cache for Nextcloud

It uses Garage's new (April 2026) `--single-node` mode together with `--default-access-key`, `--default-secret-key`, and `--default-bucket` so the cluster, access key, and bucket are all autocreated on first boot. No `garage layout assign`, no `mc admin user add`, no separate init container.

## Prerequisites

- Docker and Docker Compose v2
- ~2 GB free RAM
- Ports `8080` and `3900` available on the host
- Tested on Debian 12 with Docker 27.x

## Files

| File | Purpose |
|---|---|
| `docker-compose.yml` | Garage + Nextcloud + Postgres + Redis |
| `garage.toml` | Garage server config (mounted read-only into the container) |
| `.env.example` | Template for secrets and credentials |

## How to Run

1. Generate secrets and copy the env template:

   ```bash
   cp .env.example .env
   # GARAGE_RPC_SECRET — must be 32 hex chars (16 bytes)
   echo "GARAGE_RPC_SECRET=$(openssl rand -hex 32)" >> .env.tmp
   # admin tokens and S3 secret can be longer
   echo "GARAGE_ADMIN_TOKEN=$(openssl rand -base64 32)" >> .env.tmp
   echo "GARAGE_METRICS_TOKEN=$(openssl rand -base64 32)" >> .env.tmp
   echo "GARAGE_DEFAULT_SECRET_KEY=$(openssl rand -hex 32)" >> .env.tmp
   ```

   Then fold `.env.tmp` values into `.env` (replacing the placeholder lines) and set strong values for the Postgres and Nextcloud admin passwords too.

2. Bring it up:

   ```bash
   docker compose up -d
   ```

3. Watch Garage finish initialising — first boot creates the layout, the access key, and the bucket:

   ```bash
   docker compose logs -f garage
   ```

4. Browse to `http://localhost:8080` and complete the Nextcloud setup wizard. The S3 backend is already wired through the `OBJECTSTORE_S3_*` environment variables — Nextcloud will store every uploaded file in the Garage `nextcloud` bucket from day one.

5. Verify Garage is serving traffic:

   ```bash
   curl -I http://localhost:3900
   ```

   You should see an HTTP response from the Garage S3 endpoint (a 400 is fine — it just means you didn't sign the request).

## Tear Down

```bash
docker compose down -v
```

The `-v` removes the named volumes — that includes Garage's data and metadata, Postgres, and Nextcloud's web root. Drop it if you want to keep state.

## Troubleshooting

- **Garage exits immediately with a panic about `rpc_secret`.** The `GARAGE_RPC_SECRET` must be exactly 32 hex characters. Re-run `openssl rand -hex 32` and update `.env`.
- **Nextcloud setup screen complains about S3.** Confirm the `garage` container is healthy (`docker compose ps`), and that the `OBJECTSTORE_S3_BUCKET` value matches `GARAGE_DEFAULT_BUCKET`.
- **S3 versioning quirks.** Garage's S3 versioning support is partial — see [issue #166](https://git.deuxfleurs.fr/Deuxfleurs/garage/issues/166). Nextcloud doesn't depend on it, but other tooling might.
- **Migrating from an existing MinIO deploy.** Use `mc mirror minio-old/yourbucket garage/nextcloud` (or `rclone sync`) to copy objects across before flipping Nextcloud's config.

## License

The Compose files in this directory are released under the same license as the [sumguy-examples](https://github.com/KingPin/sumguy-examples) repo. Garage itself is AGPL-3.0; Nextcloud is AGPL-3.0; Postgres and Redis use their own licenses.
