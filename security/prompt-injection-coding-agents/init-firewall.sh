#!/usr/bin/env bash
# Default-deny egress with a small allowlist, simplified from the mechanism in
# Anthropic's reference devcontainer (.devcontainer/init-firewall.sh in
# github.com/anthropics/claude-code). Run as root, or in a container with
# --cap-add=NET_ADMIN --cap-add=NET_RAW. Needs iptables, ipset, dig.
set -euo pipefail

ALLOWED_DOMAINS="${ALLOWED_DOMAINS:-registry.npmjs.org api.anthropic.com github.com}"

# Default deny everything outbound
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# Loopback and already-established connections are fine
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# DNS has to work so the allowlist below can resolve
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

# Build the allowlist as an ipset, resolved to IPv4 addresses
ipset create allowed-domains hash:net -exist
for domain in $ALLOWED_DOMAINS; do
  for ip in $(dig +short A "$domain" | grep -E '^[0-9.]+$'); do
    ipset add allowed-domains "$ip" -exist
  done
done

# Only traffic to that set gets out. Everything else hits the DROP policy above.
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

echo "Egress locked to: $ALLOWED_DOMAINS"
