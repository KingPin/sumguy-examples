# Source me from app/: starts a throwaway Postgres for `go test` and exports PGURL.
PG_IMAGE=$(. ../bench.env; echo "$PG_IMAGE")
docker inspect mvm-testpg >/dev/null 2>&1 || docker run -d --rm --name mvm-testpg \
  -e POSTGRES_PASSWORD=pg -p 127.0.0.1:55432:5432 --tmpfs /var/lib/postgresql "$PG_IMAGE" >/dev/null
until docker exec mvm-testpg pg_isready -q -h 127.0.0.1 -U postgres; do sleep 0.5; done
export PGURL="postgres://postgres:pg@127.0.0.1:55432/postgres?sslmode=disable"
