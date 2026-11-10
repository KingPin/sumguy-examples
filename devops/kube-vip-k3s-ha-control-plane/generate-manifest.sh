#!/usr/bin/env bash
# Generate a kube-vip DaemonSet manifest for the k3s control plane (ARP mode).
# Usage: VIP=192.168.1.50 INTERFACE=eth0 ./generate-manifest.sh > kube-vip.yaml
set -euo pipefail
: "${VIP:?set VIP, e.g. VIP=192.168.1.50}"
: "${INTERFACE:?set INTERFACE, e.g. INTERFACE=eth0 (check with: ip -br addr)}"
KVVERSION="${KVVERSION:-v1.3.1}"

docker run --network host --rm "ghcr.io/kube-vip/kube-vip:${KVVERSION}" \
  manifest daemonset \
  --interface "$INTERFACE" \
  --address "$VIP" \
  --inCluster \
  --taint \
  --controlplane \
  --arp \
  --leaderElection
