# authentik-traefik

Full Authentik identity provider behind Traefik. PostgreSQL + Redis + server + worker. The minimum viable IdP for native OIDC against apps like Gitea, Grafana, Nextcloud, Portainer.

## What this proves

- Authentik web UI reachable at `https://authentik.home.internal/if/admin/`
- Healthchecks gating server/worker startup so they don't race the DB
- Postgres pinned to v16, image versions pinned so server and worker stay in lockstep
- Traefik labels for HTTPS routing

## Setup

```bash
# 1. Shared proxy network for Traefik
docker network create proxy

# 2. Generate secrets and fill .env
cp .env.example .env
sed -i "s|replace-me-with-a-long-random-password|$(openssl rand -hex 24)|" .env
sed -i "s|replace-me-with-a-long-random-secret|$(openssl rand -base64 60 | tr -d '\n')|" .env

# 3. Hosts entry (or real DNS)
echo "127.0.0.1 authentik.home.internal" | sudo tee -a /etc/hosts

# 4. Launch
docker compose up -d

# 5. Bootstrap admin
# Open https://authentik.home.internal/if/flow/initial-setup/ in your browser
# and follow the prompts to create the first admin user.
```

## Wiring up Gitea via OIDC

In Authentik:

1. **Applications → Providers → Create → OAuth2/OpenID Provider**
   - Name: `gitea`
   - Authorization flow: `default-provider-authorization-explicit-consent`
   - Redirect URIs: `https://git.home.internal/user/oauth2/authentik/callback`
   - Save the Client ID and Client Secret.
2. **Applications → Applications → Create**
   - Name: `Gitea`
   - Slug: `gitea`
   - Provider: the one you just created.
3. In Gitea: **Site Administration → Authentication Sources → Add Source**
   - Type: OAuth2
   - OAuth2 Provider: OpenID Connect
   - Client ID / Secret: from Authentik
   - OpenID Connect Auto Discovery URL: `https://authentik.home.internal/application/o/gitea/.well-known/openid-configuration`

Users hitting Gitea now see "Sign in with Authentik."

## Wiring up forward auth for non-OIDC apps

1. In Authentik: **Applications → Outposts → Create**
   - Type: `proxy`
   - Integration: `local`
2. Authentik gives you a Compose snippet for the outpost container. Deploy it on the `proxy` network.
3. Add a Traefik middleware that points at the outpost (typically `http://authentik-outpost:9000/outpost.goauthentik.io/auth/traefik`) and attach it to the service you want to protect.

## What to read next

- [Article: Authentik vs Authelia](https://sumguy.com/posts/authentik-vs-authelia/)
- [Article: Caddy vs Traefik](https://sumguy.com/posts/caddy-vs-traefik/) — proxy choice in front of Authentik
- [Article: WebAuthn / Passkeys for Sysadmins](https://sumguy.com/posts/webauthn-passkeys-sysadmins/) — strong 2FA for your users

## Tested versions

- Authentik 2024.10
- Postgres 16-alpine
- Redis 7-alpine
- Traefik 3.2
- Docker 27.3 / Compose v2.30

## Backup

Authentik's state lives in `./database/` (Postgres) and `./media/`. Back up both:

```bash
# Postgres dump
docker exec authentik-db pg_dump -U authentik authentik > authentik-db-$(date +%F).sql

# Media (uploaded logos, custom templates)
tar -czf authentik-media-$(date +%F).tar.gz ./media ./custom-templates
```

Losing the database means re-enrolling every user's TOTP and WebAuthn keys. Don't skip this.
