#!/usr/bin/env bash
# Build a tiny Docker-style bridge network by hand: two namespaces, a bridge,
# nftables masquerade, and a DNAT port forward. Usage: netns-lab.sh up|down|test
set -euo pipefail

SUBNET=10.200.0.0/24
BR_IP=10.200.0.1
RED_IP=10.200.0.2
BLUE_IP=10.200.0.3
TABLE=netns_lab

[[ $EUID -eq 0 ]] || { echo "run as root (sudo $0 $*)" >&2; exit 1; }

up() {
  down   # start clean
  ip link add br0 type bridge
  ip addr add "$BR_IP/24" dev br0
  ip link set br0 up

  for pair in "red:$RED_IP" "blue:$BLUE_IP"; do
    ns=${pair%%:*}; ip4=${pair##*:}
    ip netns add "$ns"
    ip -n "$ns" link set lo up
    ip link add "veth-$ns" type veth peer name eth0 netns "$ns"
    ip link set "veth-$ns" master br0 up
    ip -n "$ns" addr add "$ip4/24" dev eth0
    ip -n "$ns" link set eth0 up
    ip -n "$ns" route add default via "$BR_IP"
    # ip netns exec bind-mounts this over /etc/resolv.conf
    mkdir -p "/etc/netns/$ns"
    echo "nameserver 1.1.1.1" > "/etc/netns/$ns/resolv.conf"
  done

  sysctl -qw net.ipv4.ip_forward=1

  uplink=$(ip route show default | awk '/default/ {print $5; exit}')
  nft add table ip $TABLE
  nft "add chain ip $TABLE postrouting { type nat hook postrouting priority srcnat; }"
  nft "add chain ip $TABLE prerouting { type nat hook prerouting priority dstnat; }"
  nft "add chain ip $TABLE output { type nat hook output priority dstnat; }"
  nft "add chain ip $TABLE forward { type filter hook forward priority filter; policy accept; }"
  if [[ -n "$uplink" ]]; then
    nft add rule ip $TABLE postrouting ip saddr $SUBNET oifname "$uplink" masquerade
  else
    echo "warning: no default route, skipping masquerade" >&2
  fi
  # 8080 -> red:80 for outside traffic (prerouting) and for the host itself (output)
  nft add rule ip $TABLE prerouting tcp dport 8080 dnat to $RED_IP:80
  nft add rule ip $TABLE output ip daddr $BR_IP tcp dport 8080 dnat to $RED_IP:80
  # Policy is accept here. These rules only matter as a template for a default-drop table.
  nft add rule ip $TABLE forward ct state established,related accept
  nft add rule ip $TABLE forward iifname br0 accept
  nft add rule ip $TABLE forward ip daddr $RED_IP tcp dport 80 accept
  echo "lab is up: red=$RED_IP blue=$BLUE_IP bridge=$BR_IP uplink=${uplink:-none}"
}

down() {
  nft delete table ip $TABLE 2>/dev/null || true
  for ns in red blue; do
    ip netns del "$ns" 2>/dev/null || true   # also destroys veth-$ns
    rm -f "/etc/netns/$ns/resolv.conf"
    rmdir "/etc/netns/$ns" 2>/dev/null || true
  done
  ip link del br0 2>/dev/null || true
}

test_lab() {
  ip netns exec red python3 -m http.server 80 >/dev/null 2>&1 &
  server=$!
  trap 'kill $server 2>/dev/null || true' EXIT
  sleep 1
  echo "blue -> red directly:"
  ip netns exec blue curl -s -m 3 -o /dev/null -w "  %{http_code}\n" "http://$RED_IP/"
  echo "host -> $BR_IP:8080 (DNAT in the output chain):"
  curl -s -m 3 -o /dev/null -w "  %{http_code}\n" "http://$BR_IP:8080/"
}

case "${1:-}" in
  up) up ;;
  down) down ;;
  test) test_lab ;;
  *) echo "usage: $0 up|down|test" >&2; exit 2 ;;
esac
