#!/usr/bin/env bash
# The TLS settings of one HTTPS endpoint, checked from the outside with openssl and curl.
# Usage: tls.sh PORT [HOSTNAME] [ADDR]
# Needs OpenSSL 3.5 or newer on the client (for the X25519MLKEM768 probe). About a minute on loopback: one handshake per suite.
set -u
port=$1 host=${2:-app.example.test} addr=${3:-127.0.0.1}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# One handshake. The short sleep keeps stdin open so TLS 1.3 session tickets arrive before exit.
sc() { sleep 0.3 | timeout 10 openssl s_client -connect "$addr:$port" -servername "$host" "$@" 2>&1; }
# The cipher this handshake settled on, or nothing if the server refused it.
got() { grep -oE '^New, [^,]+, Cipher is [^ ]+' | grep -v '(NONE)' | awk '{print $NF}'; }
yn() { [ -n "$1" ] && echo offered || echo refused; }

echo "### 1. Protocol versions"
for v in tls1 tls1_1 tls1_2 tls1_3; do
  c=$(sc "-$v" -cipher 'DEFAULT:@SECLEVEL=0' | got)
  echo "  $v: $(yn "$c")"
done

echo "### 2. TLS 1.2 cipher suites the server accepts"
fs=0 nofs=0 cbc=0 n=0
for c in $(openssl ciphers -tls1_2 'ALL:COMPLEMENTOFALL:@SECLEVEL=0' | tr ':' ' '); do
  case $c in TLS_*) continue ;; esac   # TLS 1.3 names, tested below
  [ "$(sc -tls1_2 -cipher "$c:@SECLEVEL=0" | got)" = "$c" ] || continue
  n=$((n+1)); tags=""
  case $c in ECDHE-*|DHE-*) fs=$((fs+1)) ;; *) nofs=$((nofs+1)); tags="$tags no-FS" ;; esac
  case $c in *GCM*|*CHACHA*|*CCM*) ;; *) cbc=$((cbc+1)); tags="$tags CBC" ;; esac
  echo "  $c${tags:+  [${tags# }]}"
done
echo "  total $n: $fs forward secret, $nofs without forward secrecy, $cbc CBC"

echo "### 3. TLS 1.3 cipher suites"
for s in TLS_AES_128_GCM_SHA256 TLS_AES_256_GCM_SHA384 TLS_CHACHA20_POLY1305_SHA256 TLS_AES_128_CCM_SHA256 TLS_AES_128_CCM_8_SHA256; do
  c=$(sc -tls1_3 -ciphersuites "$s" | got)
  echo "  $s: $(yn "$c")"
done

echo "### 4. Who picks the cipher (client sends two suites in both orders)"
# Two AES-GCM suites on purpose: Go servers honor a client that lists ChaCha20 first.
a=ECDHE-RSA-AES128-GCM-SHA256 b=ECDHE-RSA-AES256-GCM-SHA384
x=$(sc -tls1_2 -cipher "$a:$b" | got); y=$(sc -tls1_2 -cipher "$b:$a" | got)
if [ -z "$x" ] || [ -z "$y" ]; then echo "  TLS 1.2: not testable (server refused $a or $b)"
elif [ "$x" = "$y" ]; then echo "  TLS 1.2: server picks ($x both times)"
else echo "  TLS 1.2: client picks"; fi
a=TLS_AES_128_GCM_SHA256 b=TLS_AES_256_GCM_SHA384
x=$(sc -tls1_3 -ciphersuites "$a:$b" | got); y=$(sc -tls1_3 -ciphersuites "$b:$a" | got)
if [ "$x" = "$y" ]; then echo "  TLS 1.3: server picks ($x both times)"; else echo "  TLS 1.3: client picks"; fi

echo "### 5. TLS 1.3 key exchange groups"
for g in X25519MLKEM768 X25519 prime256v1 secp384r1 secp521r1 ffdhe2048; do
  # The client offers only this group, so a completed handshake means the server accepts it.
  echo "  $g: $(yn "$(sc -tls1_3 -groups "$g" | got)")"
done
# openssl names a hybrid group on "Negotiated TLS1.3 group" and a classic one on "Peer Temp Key".
d=$(sc); g=$(grep -oE 'Negotiated TLS1.3 group: [^ ]+' <<<"$d" | awk '{print $NF}')
[ -n "$g" ] || g=$(grep -oE 'Peer Temp Key: [^,]+' <<<"$d" | awk '{print $NF}')
echo "  a default OpenSSL $(openssl version | awk '{print $2}') client gets: $g"

echo "### 6. Session resumption"
resumed() { sc "$@" -sess_in "$tmp/s" | grep -qE '^Reused' && echo resumed || echo 'not resumed'; }
hint() { grep -oE 'lifetime hint: [0-9]+' "$tmp/first" | head -1 | awk '{print ", lifetime hint " $NF "s"}'; }
sc -tls1_2 -sess_out "$tmp/s" > "$tmp/first"
echo "  tls1_2 session ticket issued: $(grep -q 'TLS session ticket:' "$tmp/first" && echo yes || echo no)$(hint)"
echo "  tls1_2 reconnect: $(resumed -tls1_2)"
rm -f "$tmp/s"; sc -tls1_2 -no_ticket -sess_out "$tmp/s" >/dev/null
echo "  tls1_2 reconnect without tickets (server session cache): $(resumed -tls1_2 -no_ticket)"
rm -f "$tmp/s"; sc -tls1_3 -sess_out "$tmp/s" > "$tmp/first"
echo "  tls1_3 reconnect: $(resumed -tls1_3)$(hint)"

echo "### 7. TLS 1.3 early data (0-RTT)"
rm -f "$tmp/s"; sc -tls1_3 -sess_out "$tmp/s" > "$tmp/first"
printf 'GET / HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n' "$host" > "$tmp/ed"
max=$(grep -oE 'Max Early Data: [0-9]+' "$tmp/first" | tail -1 | awk '{print $NF}')
if [ ! -s "$tmp/s" ]; then echo "  not testable: no TLS 1.3 session ticket"
elif [ "${max:-0}" -eq 0 ]; then echo "  0-RTT off: the server's tickets allow no early data"
else echo "  $(sc -tls1_3 -sess_in "$tmp/s" -early_data "$tmp/ed" | grep -oE 'Early data was (not )?[a-z]+')"
fi

echo "### 8. HSTS"
h=$(curl -skI -m 10 --resolve "$host:$port:$addr" "https://$host:$port/" | tr -d '\r' | grep -i '^strict-transport-security:')
echo "  ${h:-no Strict-Transport-Security header}"

echo "### 9. Certificate key"
sc </dev/null | openssl x509 -noout -text 2>/dev/null | grep -E 'Public Key Algorithm|Public-Key' | sed 's/^ */  /'
