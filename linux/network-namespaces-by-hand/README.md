# Network namespaces by hand

Rebuilds what `docker network create` and `docker run -p 8080:80` do, using only `ip netns`, a veth pair per namespace, a Linux bridge, and nftables.

Companion to the post: https://sumguy.com/network-namespaces-by-hand-no-docker/

## What `up` builds

- Namespaces `red` (10.200.0.2) and `blue` (10.200.0.3)
- Bridge `br0` at 10.200.0.1/24 (the "docker0")
- One veth pair per namespace, host end attached to `br0`, container end renamed `eth0`
- Default route inside each namespace via 10.200.0.1
- A per-namespace `/etc/netns/<ns>/resolv.conf` (`ip netns exec` bind-mounts it)
- nftables table `netns_lab` with masquerade for 10.200.0.0/24 out of the default-route interface, and a DNAT of port 8080 to `red:80`

If the box has no default route, the masquerade rule is skipped with a warning.

## Prerequisites

- Root
- iproute2, nftables, python3, curl
- Tested syntax with iproute2 7.2.0, nftables 1.1.7, iptables 1.8.13 (nf_tables), recent kernel

## Run

```bash
sudo ./netns-lab.sh up
sudo ./netns-lab.sh test   # blue -> red, then host -> 10.200.0.1:8080
sudo ./netns-lab.sh down   # safe to run twice
```

`test` curls the bridge address, not 127.0.0.1. A DNAT on loopback traffic needs `route_localnet` plus extra masquerading, which is the exact job Docker hands to `docker-proxy`. The post covers why.

## Warnings

- `up` sets `net.ipv4.ip_forward=1`. `down` does not turn it back off, because other things on your host may need it.
- If another nftables table or your firewall has a default-drop forward policy, forwarded traffic is still dropped. Accept rules in a separate table do not override another table's drop.
- Namespaces are not persistent. A reboot removes everything. Run `up` again.
- `down` deletes `/etc/netns/red` and `/etc/netns/blue` resolv.conf files, so do not reuse those names for your own namespaces.
