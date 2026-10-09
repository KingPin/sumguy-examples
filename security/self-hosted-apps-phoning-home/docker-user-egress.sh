#!/usr/bin/env bash
# Log and drop outbound traffic from one Docker subnet (iptables backend only).
# -I inserts at the top, so rules are added in reverse evaluation order.
# Comment out the DROP line for a log-only week first.
set -euo pipefail

SUBNET="${SUBNET:-172.20.0.0/24}"
RESOLVER="${RESOLVER:-192.168.1.2}"

iptables -I DOCKER-USER -s "$SUBNET" -j DROP
iptables -I DOCKER-USER -s "$SUBNET" -j LOG --log-prefix "egress-drop: "
iptables -I DOCKER-USER -s "$SUBNET" -d "$SUBNET" -j ACCEPT
iptables -I DOCKER-USER -s "$SUBNET" -d "$RESOLVER" -p udp --dport 53 -j ACCEPT
iptables -I DOCKER-USER -s "$SUBNET" -d "$RESOLVER" -p tcp --dport 53 -j ACCEPT
iptables -I DOCKER-USER -s "$SUBNET" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

iptables -L DOCKER-USER -n -v --line-numbers
