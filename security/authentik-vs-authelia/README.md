# authentik-vs-authelia

Working Compose setups for both options from **[Authentik vs Authelia: SSO for Your Self-Hosted Stack](https://sumguy.com/posts/authentik-vs-authelia/)** on SumGuy's Ramblings.

Two complete, runnable stacks behind Traefik. Pick the one that matches your needs.

## What's in here

| Path | What it is |
|---|---|
| `authelia-traefik/` | Authelia + Traefik + Grafana. Forward-auth flow with TOTP / WebAuthn 2FA. ~100 MB RAM for the whole auth stack. |
| `authentik-traefik/` | Authentik + Postgres + Redis + worker behind Traefik. Full OIDC identity provider. ~700 MB RAM idle. |

## Which should I run?

- **Authelia** — you want a quick login wall in front of services. Single user or small fixed team. No web admin UI; you edit YAML.
- **Authentik** — you want OIDC / SAML for apps like Gitea, Grafana, Nextcloud. Web admin UI. More moving parts.

Both work side-by-side during a migration. See the [article](https://sumguy.com/posts/authentik-vs-authelia/#migration-path-authelia-authentik) for the cutover path.

## Prerequisites

- Docker 24+ and Docker Compose v2
- A domain you control with DNS pointing at the host (or `/etc/hosts` overrides for `*.home.internal`)
- An external Docker network named `proxy` if you want Traefik to reach other stacks: `docker network create proxy`

Tested on Linux, Docker 27.3, Compose v2.30.
