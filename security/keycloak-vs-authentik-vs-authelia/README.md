# keycloak-vs-authentik-vs-authelia

Keycloak files from **[Keycloak vs Authentik vs Authelia](https://sumguy.com/keycloak-vs-authentik-vs-authelia/)** on SumGuy's Ramblings.

Keycloak in production `start` mode with Postgres, meant to sit behind a reverse proxy that terminates TLS, plus a script that creates a realm and attaches an LDAP user federation provider. For authentik, use the official compose file from the authentik install docs. Working Authelia and authentik stacks live in [`../authentik-vs-authelia/`](../authentik-vs-authelia/).

## What's in here

| File | What it is |
|---|---|
| `docker-compose.yml` | Keycloak 26.8.1 + Postgres 17. Listens on plain HTTP 8080 inside the Compose network, 2 GB memory limit. |
| `.env.example` | Database and bootstrap admin passwords. Copy to `.env`. |
| `ldap-federation.sh` | Creates realm `home` and a read-only LDAP provider via `kcadm.sh`. |

## Prerequisites

- Docker and Docker Compose v2
- A reverse proxy that can reach `keycloak:8080` (attach the service to the proxy's Docker network) and forwards `https://sso.example.com` to it and overwrites `X-Forwarded-*` headers
- An LDAP server, if you run the federation script

Tested 2026-10-20 on Linux, Docker 29.8.2, Keycloak 26.8.1.

## Run it

1. `cp .env.example .env` and set real passwords.
2. Change `KC_HOSTNAME` in `docker-compose.yml` to your public URL.
3. `docker compose up -d`
4. Wait for `Bootstrap completed` in `docker compose logs keycloak`. Requests before that get a 503.
5. Edit the LDAP URL, DNs and attributes in `ldap-federation.sh`, then run:
   ```bash
   KC_ADMIN_PASSWORD=... LDAP_BIND_PASSWORD=... ./ldap-federation.sh
   ```
6. Log in to the admin console through your proxy, create a permanent admin, and delete the temporary `admin` user. Remove the `KC_BOOTSTRAP_ADMIN_*` variables afterward.

Do not publish or proxy port 9000. It is the management interface (health and metrics).

## Tear down

```bash
docker compose down -v
```

`-v` deletes the Postgres volume and every realm in it.
