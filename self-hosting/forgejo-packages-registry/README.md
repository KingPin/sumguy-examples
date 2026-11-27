# Forgejo Packages: Docker and npm Registry

Working files for using Forgejo's built-in package registry as a private
container registry and a private npm registry.

Article: https://sumguy.com/forgejo-packages-registry/

## What's here

```
docker-compose.yml            # Forgejo 17 with per-owner package limits
app.ini.example               # the same [packages] limits for a non-Docker install
nginx/forgejo.conf            # reverse proxy with client_max_body_size raised
.forgejo/workflows/image.yml  # Forgejo Actions: build and push an image
npm/.npmrc                    # scope -> Forgejo registry, token from env
npm/package.json              # a scoped package (@homelab/utils)
npm/index.js                  # something to publish
```

## Prerequisites

- Docker and Docker Compose v2
- Node.js and npm for the npm half
- An access token with the `write:package` scope (user settings, Applications)
- Tested against: Forgejo 17.0.2, Docker 29.9.3, Compose 5.8.0, Node 24.18.1,
  npm 11.16.0 (2026-11-27)

## How to run

1. Start Forgejo and finish the web installer at http://localhost:3000:

   ```bash
   docker compose up -d
   ```

2. Push an image (replace the host with yours; `localhost` needs no TLS):

   ```bash
   docker login forgejo.example.com -u alice
   docker build -t forgejo.example.com/alice/webapp:1.0 .
   docker push forgejo.example.com/alice/webapp:1.0
   ```

3. Publish the npm package. Create an org named `homelab` first, edit the host
   in `npm/.npmrc`, then:

   ```bash
   cd npm
   export FORGEJO_NPM_TOKEN="<your access token>"
   npm publish
   ```

4. For CI, copy `.forgejo/workflows/image.yml` into your repo and add a
   `REGISTRY_TOKEN` secret holding a `write:package` token.

## What the test run showed

Run against a throwaway Forgejo 17.0.2 container on 2026-11-27:

- `docker push` of `webapp:Beta` stored the tag as `beta` (tags are
  case-insensitive), and nested names like `alice/my/image` pushed fine.
- Publishing an existing npm version fails. After `npm unpublish`, the same
  version republished immediately.
- `npm unpublish` of the only version is refused by the npm client unless you
  pass `--force`.
- An auth line written as `https://host/...:_authToken=` (with the scheme)
  made `npm publish` fail with `ENEEDAUTH`.
- `npm dist-tag add pkg@1.0.0 1.2.3` is rejected: tag names cannot be versions.
