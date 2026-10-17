# IoT VLAN with cross-VLAN Chromecast discovery

Companion files for [IoT VLANs That Don't Break Chromecast](https://sumguy.com/iot-vlans-without-breaking-chromecast/).

Smart plugs, TVs, and Cast devices live on VLAN 20 (`10.0.20.0/24`). Trusted devices live on VLAN 10 (`10.0.10.0/24`). The firewall lets trusted start connections into IoT and lets IoT reach only Home Assistant. An Avahi reflector copies mDNS between the two VLANs so the cast button comes back.

## Files

- `nftables.conf`: the router policy. Trusted to IoT open, IoT to trusted limited to `10.0.10.50:8123`, both to WAN, mDNS accepted on the router itself.
- `avahi/avahi-daemon.conf`: Avahi in reflector mode, limited to `eth0.10` and `eth0.20`. Uncomment `reflect-filters` to reflect only Cast and AirPlay.
- `compose.yaml`: runs that Avahi config in an Alpine container with host networking. It deletes the package's default `ssh` and `sftp-ssh` service files first, so the reflector host does not advertise its own SSH into the IoT VLAN.
- `systemd-network/`: persistent VLAN 20 sub-interface for systemd-networkd.

## Prerequisites

- A Linux host with a trunk port carrying both VLANs (the router itself, or a box with `eth0.10` and `eth0.20`). Rename the interfaces in every file to match yours.
- Docker with Compose v2 for the reflector container.
- Stop any Avahi already on the host first (`sudo systemctl disable --now avahi-daemon.socket avahi-daemon.service`), or the two fight over UDP 5353.

Tested versions (October 2026): Alpine 3.24.2, Avahi 0.9-rc4, nftables 1.1.6, Docker Compose v5.6.0. The Compose file was started on a host and logged "Server startup complete"; the nftables file passed `nft -c`.

## Run

```bash
# Router policy
sudo nft -c -f nftables.conf    # syntax check only
sudo nft -f nftables.conf

# Persistent VLAN interface
sudo cp systemd-network/* /etc/systemd/network/
sudo networkctl reload

# Reflector
docker compose up -d
docker compose logs -f avahi-reflector   # look for "Server startup complete"
```

Check discovery from the trusted side:

```bash
avahi-browse -art | grep -A3 _googlecast
sudo tcpdump -ni eth0.20 udp port 5353
```

## Rollback

`docker compose down` stops the reflector. Devices keep working inside their own VLAN. Only cross-VLAN discovery stops.
