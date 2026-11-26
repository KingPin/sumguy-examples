# OpenWrt as a dumb access point, with guest and IoT VLAN SSIDs

Companion files for [OpenWrt as a Dumb Access Point](https://sumguy.com/openwrt-dumb-access-point/).

The OpenWrt router becomes a bridged access point. The main router keeps DHCP, DNS, firewall, and routing. Optionally, extra SSIDs (guest, IoT) ride to the main router as tagged VLANs over the uplink cable. The AP gets no IP address on those VLANs and routes nothing for them.

## Files

- `dumb-ap.sh`: UCI batch script. Static IP, gateway, DNS, DHCP/RA off, optional WAN port into `br-lan`, SSID and encryption on every `default_radioN` section. Variables sit at the top.
- `vlan-ssids.sh`: adds `bridge-vlan` sections plus guest and IoT `proto none` interfaces and SSIDs. Run it after `dumb-ap.sh`, once.
- `config/network`, `config/dhcp`, `config/wireless`: the AP's config files after both scripts ran with the default variables. This is the output of `uci export`, trimmed.
- `config/main-router-network.example`: what the main router needs (VLAN trunk, per-VLAN DHCP, guest and IoT firewall zones). An example, not tested on hardware.
- `test/run-test.sh`: the container test described below. `test/last-run.txt` is its output.

## Prerequisites

- An OpenWrt router with a DSA switch (`br-lan` plus `bridge-vlan` sections). Older swconfig devices need `switch_vlan` sections instead; `vlan-ssids.sh` does not cover them.
- A free IP on the main LAN outside the main router's DHCP pool.
- For the VLAN part: a main router that can tag VLANs 20 and 30 on the port that feeds the AP.
- A PC cabled to an AP LAN port (not WAN) for the first run, with PC Wi-Fi off.

Tested versions (November 2026): OpenWrt 25.12.6 (`openwrt/rootfs:x86_64-25.12.6` container). Both scripts ran to completion and `uci export` matched `config/`. **Not tested:** wireless (no radio in a container), `netifd` applying the config, VLAN tagging on a real switch, and the main-router example. Treat the Wi-Fi and VLAN behaviour as untested on hardware.

## Run

Edit the variables at the top of each script, copy them to the AP, and run:

```bash
scp dumb-ap.sh vlan-ssids.sh root@192.168.1.1:/tmp/
ssh root@192.168.1.1 'sh /tmp/dumb-ap.sh'
ssh root@192.168.1.1 'sh /tmp/vlan-ssids.sh'   # optional
ssh root@192.168.1.1 'reboot'
```

After the reboot, move the uplink cable to a LAN port (or the former WAN port if `ADD_WAN_PORT=1`) and reach the AP at its new address.

Run the container test yourself:

```bash
docker run --rm -v "$PWD":/work:ro openwrt/rootfs:x86_64-25.12.6 sh /work/test/run-test.sh
```

## Rollback

Neither script restarts anything, so a mistake only bites at reboot. Both scripts commit, so `uci revert` no longer helps. To get back in, boot failsafe mode (press a button while the LED blinks early in boot, then use 192.168.1.1 from a PC with a static address) and fix `/etc/config/network`. To start over, run `firstboot -y && reboot`, which wipes the config.
