# PrivateBin vs Hemmelig: self-destructing secrets

Two Docker Compose stacks for sharing secrets that delete themselves after a read or a timer. Both encrypt in the browser and keep the key in the URL fragment, so the server stores only ciphertext.

Article: https://sumguy.com/privatebin-vs-hemmelig/

## Contents

```text
privatebin/   docker-compose.yml + conf.php (burn-after-reading on by default, 1 day expiry)
hemmelig/     docker-compose.yml + .env.example
```

## Prerequisites and tested versions

Tested 2 November 2026 with Docker Compose v2.

| Stack | Image | Notes |
|---|---|---|
| PrivateBin | `privatebin/nginx-fpm-alpine:2.1.0` | Listens on 8080 inside the container |
| Hemmelig | `hemmeligapp/hemmelig:v7.6.1` | Final release. The upstream repository is archived. Listens on 3000 |

Both stacks bind to `127.0.0.1`. Put a TLS-terminating reverse proxy in front of them. The browser Web Crypto API needs HTTPS.

## Run PrivateBin

```bash
cd privatebin
docker compose up -d
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8080/   # 200
```

The `conf.php` must keep its first line (`;<?php http_response_code(403); /*`) and must contain the `[model]` and `[model_options]` sections, or PrivateBin returns a 500 error.

## Run Hemmelig

```bash
cd hemmelig
cp .env.example .env
# set BETTER_AUTH_SECRET (openssl rand -base64 32) and PUBLIC_URL in .env
docker compose up -d
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3000/   # 200
```

`PUBLIC_URL` must match the URL you type in the browser. For a local test, use `http://localhost:3000`.

## What was tested

- PrivateBin: the page returned 200 with "Burn after reading" pre-checked. A paste created through the JSON API with placeholder ciphertext was readable once, and a second read returned the "does not exist" error. A plain GET of the paste page did not consume it.
- Hemmelig: the container reported healthy and the page returned 200. A secret created through `POST /api/secrets` with placeholder ciphertext and `views: 1` was revealed once by `POST /api/secrets/<id>`, and the second reveal returned 404.
- Not tested: a full browser encrypt and decrypt round trip, and link previewers that run JavaScript.

## Clean up

```bash
docker compose down -v
```

This deletes the data volumes and every stored secret.
