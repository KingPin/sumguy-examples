# authelia-traefik

Minimal Authelia + Traefik + Grafana stack. Authelia gates everything via `forwardAuth`. Grafana auto-creates users from the `Remote-User` header.

## What this proves

- Authelia checking every request to `grafana.home.internal`
- One-factor (password) policy by default, two-factor for sensitive subdomains
- Grafana receiving `Remote-User: <username>` and logging the user in automatically
- TOTP and WebAuthn registered through the Authelia portal at `auth.home.internal`

## Setup

```bash
# 1. Create the shared proxy network if you don't have it
docker network create proxy

# 2. Generate Authelia's three secrets
mkdir -p config/secrets
openssl rand -hex 32 > config/secrets/JWT_SECRET
openssl rand -hex 32 > config/secrets/SESSION_SECRET
openssl rand -hex 32 > config/secrets/STORAGE_ENCRYPTION_KEY
chmod 600 config/secrets/*

# 3. Generate a real password hash and paste it into config/users.yml
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'your-actual-password'

# 4. Add hosts entries (or real DNS) for the test domains
echo "127.0.0.1 auth.home.internal grafana.home.internal" | sudo tee -a /etc/hosts

# 5. Launch
docker compose up -d
```

## Try it

Open `https://grafana.home.internal/`. Traefik bounces you to `auth.home.internal/login`. Log in as `kingpin` / your password. Register TOTP. Get bounced back to Grafana, logged in.

## What to read next

- [Article: Authentik vs Authelia](https://sumguy.com/posts/authentik-vs-authelia/)
- [Article: Vaultwarden Behind Authelia](https://sumguy.com/posts/vaultwarden-behind-authelia/) — the same pattern in front of Vaultwarden
- [Article: Caddy vs Traefik](https://sumguy.com/posts/caddy-vs-traefik/) — swap Traefik for Caddy

## Tested versions

- Authelia 4.38+
- Traefik 3.2
- Grafana 11.x
- Docker 27.3 / Compose v2.30
