# Outline team wiki with Dex SSO

Outline, Postgres, Redis, and Dex (an OIDC provider) in one Compose file. Outline has no password login, so Dex supplies the sign-in.

Article: https://sumguy.com/outline-team-wiki/

## Files

| File | Purpose |
| --- | --- |
| `compose.yaml` | Outline, Postgres 18, Redis 8, Dex, with a network alias so the browser and the Outline container reach Dex under one name |
| `config.yaml` | Dex config: issuer, one static client for Outline, one demo user |
| `.env.example` | Outline environment variables, including the OIDC settings and the three secrets to generate |

## Prerequisites

- Docker with the Compose plugin.
- Ports 3000 and 5556 free on the host.
- A browser that resolves `dex.localtest.me` to `127.0.0.1` (public DNS does this; no `/etc/hosts` edit).

Tested against: Outline 1.11.0, Dex v2.46.0, Postgres 18, Redis 8.10.2, Docker Compose v2. Verified: all four containers start, Outline runs its migrations, Dex serves `/.well-known/openid-configuration`, `/api/auth.config` lists the OIDC provider, `/auth/oidc` returns a 302 to Dex, and a scripted login as the demo user ends in a session with the `admin` role.

## Run

```bash
cp .env.example .env
for k in SECRET_KEY UTILS_SECRET OIDC_CLIENT_SECRET POSTGRES_PASSWORD; do
  sed -i "s/^$k=.*/$k=$(openssl rand -hex 32)/" .env
done
docker compose up -d
```

Open http://localhost:3000, click the Dex button, and sign in as `admin@example.com` with the password `password`. The first user to sign in creates the workspace and becomes its admin.

Clean up with `docker compose down -v`. The `-v` deletes the database and uploads.

## Make it real

- Replace `localhost:3000` and `dex.localtest.me:5556` with real HTTPS hostnames in `.env` and `config.yaml`. The Dex issuer must be identical in both files and in the Dex `redirectURIs`.
- Set `FORCE_HTTPS=true` (or remove the line) once TLS terminates in front of Outline.
- Replace the demo user. Generate a bcrypt hash with `docker run --rm httpd:2 htpasswd -bnBC 10 "" 'your-password' | tr -d ':\n'` (Dex accepts the `$2y` prefix as is) and paste it into `hash`.
- Pin the image tags and upgrade on purpose.
