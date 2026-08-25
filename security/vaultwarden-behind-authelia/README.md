# Vaultwarden Behind Authelia

Vaultwarden with Authelia forward auth in front of it, using Caddy as the
reverse proxy, with a path split that does not break the Bitwarden mobile,
desktop, CLI, or browser-extension clients.

Article: https://sumguy.com/vaultwarden-behind-authelia/

## The point of this example

Most published configs for this stack put `/identity` behind the `two_factor`
policy. That path carries `/identity/accounts/prelogin` and
`/identity/connect/token`, the first two calls every Bitwarden client makes, so
protecting it means no native client can log in at all. The web vault still
works, which is why the mistake survives review.

`/attachments/*` has the same problem: it is a client download route with its
own signed token in the query string, not a human-facing page.

The bypass list here is the full set of client paths:

```
/api/*  /identity/*  /attachments/*  /icons/*
/events/*  /notifications/*  /.well-known/*  /alive
```

Authelia is left guarding `/` (web vault UI) and `/admin`. That is a smaller
surface than most guides claim. Anyone holding your master password can still
authenticate at `/identity/connect/token` and sync the vault without seeing an
Authelia prompt, so Vaultwarden's own two-step login stays mandatory and
fail2ban covers the rest.

## Files

| File | What it is |
| --- | --- |
| `compose.yaml` | Caddy, Authelia, Redis, Postgres, Vaultwarden |
| `Caddyfile` | The path split, using mutually exclusive `handle` blocks |
| `authelia/configuration.yml` | Authelia 4.39 config, access control rules |
| `authelia/users.yml` | File-backed user database |
| `gen-secrets.sh` | Creates the secret files the compose file mounts |
| `backup-vaultwarden.sh` | SQLite-safe backup of Vaultwarden and Authelia |
| `fail2ban/` | Filter and jail for the bypassed login path |

## Prerequisites

Tested with:

- Vaultwarden 1.37.2
- Authelia 4.39.20
- Caddy 2.11
- PostgreSQL 18, Redis 8.10
- Docker Engine 27+ with Compose v2

You need two DNS records pointing at the host, on the same parent domain:
`vault.yourdomain.com` and `auth.yourdomain.com`. Authelia's session cookie is
scoped to the parent domain, so the portal cannot live on a different one.

## How to run it

1. Replace every `yourdomain.com` in `compose.yaml`, `Caddyfile`, and
   `authelia/configuration.yml` with your own domain.
2. Generate the secrets:
   ```bash
   ./gen-secrets.sh
   ```
3. Put your real SMTP password in `authelia/secrets/smtp_password`.
4. Generate an Authelia password hash and paste it into `authelia/users.yml`:
   ```bash
   docker run --rm authelia/authelia:4.39 \
     authelia crypto hash generate argon2 --password 'YourPasswordHere'
   ```
5. Generate the Vaultwarden admin token and paste it into `compose.yaml`:
   ```bash
   docker run --rm -it vaultwarden/server:1.37.2 /vaultwarden hash --preset owasp
   ```
6. Bring it up:
   ```bash
   docker compose up -d
   docker compose logs -f authelia
   ```
   Wait for `Startup complete`.
7. Browse to `https://vault.yourdomain.com`, get redirected to the Authelia
   portal, log in, and enroll TOTP.

## Verifying the bypass list

Do these in order. Test 2 is the one that catches the common mistake:

1. Browse to `https://vault.yourdomain.com`. You should hit Authelia first.
2. **Sign out of the Bitwarden mobile app completely, then sign back in.** A
   cached session hides a broken `/identity`, so testing sync on an
   already-logged-in app proves nothing. A login error here means `/identity/*`
   is missing from the bypass list.
3. Download a file attachment on mobile. This exercises `/attachments/*`.
4. Browse to `/admin`. You should get Authelia, then the token prompt.

## Notes

- `WEBSOCKET_ENABLED` no longer exists. Vaultwarden serves the notifications
  hub on the main HTTP port and the current variable is `ENABLE_WEBSOCKET`,
  which defaults to `true`. Nothing to set.
- `IP_HEADER` is set to `X-Forwarded-For` and the Caddyfile also sets
  `X-Real-IP`. Without one of the two, every failed login logs the Caddy
  container's address and fail2ban bans your own proxy.
- Authelia's `regulation.modes` defaults to `['user']`, which bans the account
  rather than the source IP. Both modes are enabled here.
- Secrets are supplied only through `_FILE` environment variables. Authelia
  refuses to start if a value is set in both the config file and an env var.
- `authelia/secrets/` is gitignored. Do not commit it.

- The optional Authelia OIDC provider block for Vaultwarden SSO is in the
  article rather than here; this example covers the ForwardAuth setup.
