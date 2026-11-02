# Shlink vs YOURLS: companion files

Two self-contained Compose stacks for the post [Shlink vs YOURLS: Self-Hosted Short Links](https://sumguy.com/shlink-vs-yourls/). Run one or both. They use different default ports and do not share anything.

| Stack | Services | Default ports (localhost only) |
| --- | --- | --- |
| `shlink/` | Shlink, PostgreSQL, Shlink web client | 8080 (API + redirects), 8000 (web client) |
| `yourls/` | YOURLS (Apache), MariaDB | 8081 (admin + redirects) |

## Tested versions

Tested 2026-11-02 with Docker 29.9.2 and Docker Compose 5.6.1.

- `shlinkio/shlink:5.1.8` (RoadRunner image)
- `shlinkio/shlink-web-client:4.9.0`
- `postgres:17-alpine`
- `yourls:1.10.6-apache`
- `mariadb:11.4`

## Run Shlink

```bash
cd shlink
cp .env.example .env
# edit .env: set INITIAL_API_KEY and DB_PASSWORD
docker compose up -d
curl localhost:8080/rest/health
```

Create a short URL through the REST API:

```bash
curl -s -X POST localhost:8080/rest/v3/short-urls \
  -H "X-Api-Key: $INITIAL_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"longUrl":"https://example.com/some/long/path","customSlug":"demo"}'
curl -I localhost:8080/demo
```

Or use the CLI inside the container:

```bash
docker compose exec shlink shlink api-key:generate --name=laptop
docker compose exec shlink shlink short-url:create https://example.com/cli -c cli1
```

The web client at `http://localhost:8000` is preloaded with the server URL and the `INITIAL_API_KEY`. Anyone who can reach the web client port can use that key, so keep it bound to localhost or put it behind auth.

`GEOLITE_LICENSE_KEY` is optional. Without it Shlink works but visits get no country or city.

## Run YOURLS

```bash
cd yourls
cp .env.example .env
# edit .env: set YOURLS_PASS, DB_PASSWORD, DB_ROOT_PASSWORD
docker compose up -d
```

Open `http://localhost:8081/admin/` and click "Install YOURLS" once. Then log in with `YOURLS_USER` and `YOURLS_PASS`. The signature token for the API is on the Tools page of the admin UI.

Gotcha: the `yourls:1.10.6-apache` image listens on port 8080 inside the container, not 80. The Compose file maps to 8080 for that reason.

## Clean up

```bash
docker compose down -v
```

`-v` deletes the database volume and every link in it.
