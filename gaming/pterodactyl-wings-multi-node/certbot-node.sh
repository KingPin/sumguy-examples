#!/usr/bin/env bash
# Per-node Let's Encrypt certificate for Wings. Run as root on the node.
# The Panel generates cert paths of /etc/letsencrypt/live/<fqdn>/fullchain.pem
# and privkey.pem, which is exactly where certbot writes them.
set -euo pipefail

FQDN="${1:?usage: certbot-node.sh node2.example.com [standalone|dns]}"
METHOD="${2:-standalone}"

apt-get update
apt-get install -y certbot

case "$METHOD" in
  standalone)
    # Needs port 80 free and reachable from the internet.
    certbot certonly --standalone -d "$FQDN"
    ;;
  dns)
    # Prints a TXT record to create. No inbound port 80 needed.
    certbot certonly --manual --preferred-challenges dns -d "$FQDN"
    ;;
  *)
    echo "method must be standalone or dns" >&2
    exit 1
    ;;
esac

# Restart Wings after each successful renewal so it loads the new certificate.
# The distro certbot package already runs `certbot renew` on a timer; this
# deploy hook rides along with it. Standalone renewal needs port 80 free.
# Note: manual DNS certificates do not auto-renew; use a DNS plugin for that.
install -d /etc/letsencrypt/renewal-hooks/deploy
printf '#!/bin/sh\nsystemctl restart wings\n' > /etc/letsencrypt/renewal-hooks/deploy/restart-wings.sh
chmod 755 /etc/letsencrypt/renewal-hooks/deploy/restart-wings.sh
