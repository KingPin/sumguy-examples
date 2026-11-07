#!/usr/bin/env bash
# Admin-path probes against one proxy. Run by run.sh with the compose project up.
# Usage: probe.sh SERVICE PROXY_IP
# Every request goes to https://app.example.test (or traefik.example.test) at PROXY_IP over the lab network.
# "ADMIN PANEL" means the Express admin router answered: the request got past the proxy and into the panel.
set -u
svc=$1 ip=$2
cookie='Cookie: session=alice-ok'

# req CLIENT HOST PATH [curl args...]: one line, "status  path  ->  what came back"
req() {
  local client=$1 host=$2 path=$3; shift 3
  local out
  out=$(docker compose exec -T "$client" curl -s -k -m 10 --path-as-is \
        --resolve "$host:443:$ip" -w '\n%{http_code}' "$@" "https://$host$path")
  local code=${out##*$'\n'} body=${out%$'\n'*}
  if grep -q '"admin_panel":true' <<<"$body"; then
    body="ADMIN PANEL $(grep -o '"path":"[^"]*"\|"host":"[^"]*"\|"remote_user":[^,}]*' <<<"$body" | tr '\n' ' ')"
  else
    body=$(head -c 90 <<<"$body" | tr '\n' ' ')
  fi
  printf '%-4s %-26s -> %s\n' "$code" "$path" "$body"
}

# raw CLIENT [curl args...]: status and the first 160 bytes of the body, or why there was no answer
raw() {
  local client=$1; shift
  local out rc
  out=$(docker compose exec -T "$client" curl -s -m 5 -w '\n%{http_code}' "$@"); rc=$?
  if [ $rc -ne 0 ]; then echo "no answer (curl exit $rc)"; return; fi
  echo "${out##*$'\n'} $(head -c 160 <<<"${out%$'\n'*}" | tr '\n' ' ')"
}

echo "### $svc ($ip)"

echo "== 1. admin path variants from a stranger (client-out, 172.31.50.102, no session)"
for p in /admin /admin/ /admin/users /ADMIN /Admin/users //admin /./admin /api/../admin \
         /%61dmin /%41DMIN /admin%2Fusers /admin%20 /admin.; do
  req client-out app.example.test "$p"
done

echo "== 2. the real admin (client-lan, 172.31.50.101, with a session cookie)"
for p in /admin /admin/ /admin/users; do
  req client-lan app.example.test "$p" -H "$cookie"
done
echo "-- client-lan without a session"
req client-lan app.example.test /admin/

echo "== 3. identity header: can a client choose who the app thinks it is?"
echo "-- stranger, public route, sends Remote-User: alice"
req client-out app.example.test /whoami -H 'Remote-User: alice'
echo "-- admin with a valid session as alice, also sends Remote-User: root"
req client-lan app.example.test /admin/ -H "$cookie" -H 'Remote-User: root'
echo "-- LAN client, no session, a path the auth server bypasses (200 with no Remote-User), sends Remote-User: root"
req client-lan app.example.test /admin/health -H 'Remote-User: root'

echo "== 4. control plane"
case $svc in
  traefik)
    echo "-- stranger to Traefik's own API port, http://$ip:8080/api/rawdata"
    code=$(docker compose exec -T client-out curl -s -m 5 -o /tmp/raw -w '%{http_code}' "http://$ip:8080/api/rawdata"); rc=$?
    [ $rc -ne 0 ] && echo "no answer (curl exit $rc)" || echo "$code"
    docker compose exec -T client-out sh -c 'test -s /tmp/raw || exit 0; printf "routers: %s, services: %s, backend address shown: %s\n" \
      "$(grep -o "\"[a-z0-9-]*@[a-z]*\":{\"entryPoints\"" /tmp/raw | wc -l)" \
      "$(grep -o "\"[a-z0-9-]*@[a-z]*\":{\"loadBalancer\"" /tmp/raw | wc -l)" \
      "$(grep -o "http://172[0-9.]*:8080" /tmp/raw | head -1)"
      printf "forward-auth address shown: %s, allow list shown: %s\n" \
      "$(grep -o "http://auth:[0-9]*/verify" /tmp/raw | head -1)" \
      "$(grep -o "172\.31\.50\.101/32" /tmp/raw | head -1)"; rm -f /tmp/raw'
    echo "-- dashboard hostname, stranger / LAN with session"
    req client-out traefik.example.test /dashboard/
    req client-lan traefik.example.test /dashboard/ -H "$cookie"
    req client-lan traefik.example.test /api/version -H "$cookie"
    ;;
  caddy)
    echo "-- stranger to Caddy's admin API, http://$ip:2019/config/"
    raw client-out "http://$ip:2019/config/"
    echo "-- same, with Host: localhost:2019"
    raw client-out -H 'Host: localhost:2019' "http://$ip:2019/config/"
    echo "-- stranger replaces the whole config (POST /load), then fetches http://$ip/"
    raw client-out -H 'Content-Type: application/json' -X POST "http://$ip:2019/load" \
      -d '{"apps":{"http":{"servers":{"x":{"listen":[":80"],"routes":[{"handle":[{"handler":"static_response","body":"owned"}]}]}}}}}'
    sleep 1
    raw client-out "http://$ip/"
    docker compose restart caddy >/dev/null 2>&1; sleep 3
    echo "-- caddy reload from inside the container (the admin's own tool)"
    docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1; echo "exit $?"
    ;;
  nginx)
    echo "-- nginx open source has no admin API (no test)"
    ;;
esac
