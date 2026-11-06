#!/usr/bin/env bash
# Rate-limit probes against one origin proxy. Run by run.sh with the compose project up.
# Usage: probe.sh SERVICE CDN_PORT ORIGIN_IP
# Each test restarts SERVICE first so it starts with empty rate-limit state.
# A request "got through" when the app answered: 401 for /login (wrong password), 200 for /api/items.
set -u
svc=$1 port=$2 origin=$3
cdn=http://172.31.40.10:$port
login_body='user=admin&pass=guess'

# fire CLIENT COUNT METHOD PATH ROUTE [XFF_PREFIX]
# Sends COUNT requests at once from CLIENT. ROUTE is cdn or direct. With XFF_PREFIX, request N carries
# "X-Forwarded-For: XFF_PREFIX.N", a different fake address every time.
# Prints one line per request: status, seconds, Retry-After. The per-test listing counts status + Retry-After.
fire() {
  local client=$1 n=$2 method=$3 path=$4 route=$5 xff=${6:-} args=(-Z --parallel-immediate --parallel-max 50) i
  for i in $(seq "$n"); do
    [ "$i" -gt 1 ] && args+=(--next)
    args+=(-s -k -o /dev/null -m 90 -w '%{http_code} %{time_total}s retry-after=%header{retry-after}\n')
    [ "$method" = POST ] && args+=(-X POST -d "$login_body")
    [ -n "$xff" ] && args+=(-H "X-Forwarded-For: $xff.$i")
    if [ "$route" = cdn ]; then
      args+=("$cdn$path?$i")
    else
      args+=(--resolve "app.example.test:443:$origin" "https://app.example.test$path?$i")
    fi
  done
  docker compose exec -T "$client" curl "${args[@]}"
}

# summary OK_CODE: "20 sent, 6 got through (401) | 429 x14 | slowest 0.01s"
summary() {
  awk -v ok="$1" '{n++; c[$1]++; t=$2+0; if (t>max) max=t}
    END {printf "%d sent, %d got through (%s)", n, c[ok]+0, ok
         for (k in c) if (k!=ok) printf " | %s x%d", k, c[k]
         printf " | slowest %.2fs\n", max}'
}

reset() {
  docker compose restart "$svc" >/dev/null 2>&1
  local i
  for i in $(seq 30); do
    [ "$(docker compose exec -T client-e curl -s -o /dev/null -w '%{http_code}' -m 3 "$cdn/")" = 200 ] && return
    sleep 1
  done
  echo "!! $svc not answering through the CDN after restart"
}

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

echo "### $svc (CDN port $port, origin $origin)"

reset
echo "== whoami: what the app sees for client-b (172.31.40.102) through the CDN"
docker compose exec -T client-b curl -s -m 10 "$cdn/whoami"

reset
echo "== brute force: client-a sends 20 logins at once through the CDN; client-b tries 3 one second later"
fire client-a 20 POST /login cdn > $tmp/attack &
sleep 1
fire client-b 3 POST /login cdn > $tmp/bystander
wait
echo "attacker  (client-a): $(summary 401 < $tmp/attack)"
echo "bystander (client-b): $(summary 401 < $tmp/bystander)"
echo "-- attacker, every request by time"; sort -t" " -k2 -g $tmp/attack
echo "-- bystander"; cat $tmp/bystander
echo "-- one more attacker login, full response (minus the CDN's own Date, Server, Connection):"
docker compose exec -T client-a curl -s -m 90 -i -X POST -d "$login_body" "$cdn/login" | tr -d '\r' \
  | grep -viE '^(date|server|connection):'


reset
echo "== spoof, direct: client-c skips the CDN, 20 logins, each with a different fake X-Forwarded-For"
fire client-c 20 POST /login direct 10.66.0 | tee $tmp/c | cut -d" " -f1,3 | sort | uniq -c
echo "client-c: $(summary 401 < $tmp/c)"

reset
echo "== spoof, through the CDN: client-d, 20 logins, each with a different fake X-Forwarded-For on the left"
fire client-d 20 POST /login cdn 10.77.0 | tee $tmp/d | cut -d" " -f1,3 | sort | uniq -c
echo "client-d: $(summary 401 < $tmp/d)"

reset
echo "== page load: client-e fires 30 API calls at once through the CDN"
fire client-e 30 GET /api/items cdn | tee $tmp/e | cut -d" " -f1,3 | sort | uniq -c
echo "client-e: $(summary 200 < $tmp/e)"
