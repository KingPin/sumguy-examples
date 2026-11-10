#!/usr/bin/env bash
# Bring up a 3-server k3s cluster with kube-vip, kill the VIP holder,
# and time how long the VIP stops answering. Run from this directory.
# Usage: ./failover-test.sh            (cleans up afterwards)
#        KEEP=1 ./failover-test.sh     (leaves the cluster running)
set -euo pipefail
cd "$(dirname "$0")"
VIP=172.31.250.100
KVVERSION="${KVVERSION:-v1.3.1}"

dump() { for c in kv-server1 kv-server2 kv-server3; do
  docker inspect -f '{{.Name}} {{.State.Status}} exit={{.State.ExitCode}}' "$c" 2>/dev/null || true; done; }
cleanup() { dump; [[ "${KEEP:-0}" == 1 ]] || docker compose down -v >/dev/null 2>&1 || true; }
trap cleanup EXIT

mkdir -p manifests
cp ../rbac.yaml manifests/kube-vip-rbac.yaml
VIP=$VIP INTERFACE=eth0 KVVERSION=$KVVERSION ../generate-manifest.sh > manifests/kube-vip.yaml

kc() { docker exec kv-server1 kubectl "$@"; }

# Joining servers exit if server1 is not serving yet, so start it alone first.
docker compose up -d server1
echo "waiting for server1..."
for _ in $(seq 1 120); do
  kc get nodes >/dev/null 2>&1 && break
  sleep 2
done
docker compose up -d server2 server3

echo "waiting for 3 Ready servers..."
for _ in $(seq 1 120); do
  ready=$(kc get nodes --no-headers 2>/dev/null | grep -c ' Ready ' || true)
  [[ "$ready" == 3 ]] && break
  sleep 2
done
kc get nodes
echo "waiting for kube-vip pods on all 3 servers..."
for _ in $(seq 1 120); do
  running=$(kc -n kube-system get pods -l app.kubernetes.io/name=kube-vip-ds --no-headers 2>/dev/null | grep -c Running || true)
  [[ "$running" == 3 ]] && break
  sleep 2
done
kc -n kube-system get pods -l app.kubernetes.io/name=kube-vip-ds -o wide

echo "waiting for the VIP to answer..."
for _ in $(seq 1 120); do
  code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 1 "https://$VIP:6443/livez" || true)
  [[ "$code" != 000 ]] && break
  sleep 1
done
echo "VIP answers with HTTP $code (401 is fine: it means the API server replied)"

leader=$(kc -n kube-system get lease plndr-cp-lock -o jsonpath='{.spec.holderIdentity}')
echo "lease plndr-cp-lock holder: $leader"
for n in 1 2 3; do
  docker exec kv-server$n ip -br addr show eth0 | grep -q "$VIP" && echo "VIP is on kv-server$n"
done

# Certificate check: the VIP must be in the serving cert SANs.
echo | openssl s_client -connect "$VIP:6443" 2>/dev/null \
  | openssl x509 -noout -ext subjectAltName | tr ',' '\n' | grep -q "$VIP" \
  && echo "serving cert lists $VIP"

echo "killing $leader (docker kill = pulled power cord)..."
start=$(date +%s.%N)
docker kill "$leader" >/dev/null
sleep 0.2
down=0
for _ in $(seq 1 300); do
  code=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 1 "https://$VIP:6443/livez" || true)
  if [[ "$code" != 000 ]]; then break; fi
  down=1
  sleep 0.2
done
end=$(date +%s.%N)
printf 'VIP answered again after %.1f s (down=%s)\n' "$(awk -v a="$start" -v b="$end" 'BEGIN{print b-a}')" "$down"

survivor=$(docker ps --format '{{.Names}}' | grep kv-server | head -1)
docker exec "$survivor" kubectl -n kube-system get lease plndr-cp-lock -o jsonpath='new holder: {.spec.holderIdentity}{"\n"}'
