#!/usr/bin/env bash
# Fake "app": one insert pair per iteration against whatever host is in .target.
# Writing "pause" into .target stops writes. Writing "old" or "new" resumes them.
cd "$(dirname "$0")"
n=0
while [ ! -f .stop ]; do
  t=$(cat .target)
  if [ "$t" = pause ]; then sleep 0.02; continue; fi
  if docker compose exec -T "$t" psql -U postgres -d app -q -v ON_ERROR_STOP=1 \
    -c "WITH c AS (INSERT INTO customers (email) VALUES ('live' || now()) RETURNING id) INSERT INTO events (customer_id, kind) SELECT id, 'live' FROM c"; then
    n=$((n+1))
  else
    echo "write failed on $t at $(date +%T.%N)" >> load.errors
  fi
done
echo "$n" > load.count
