#!/bin/sh
# Add guest and IoT SSIDs as tagged VLANs on an AP that already ran dumb-ap.sh.
# DSA devices only (br-lan with bridge-vlan sections). The AP does no routing
# for these VLANs: the main router owns DHCP, DNS, and the isolation rules.
# Commits the config. Does NOT restart anything.

# ---- edit these ----
UPLINK="lan1"                   # the port cabled to the main router
LAN_PORTS="lan1 lan2 lan3 lan4 wan"   # every port inside br-lan, uplink included
GUEST_VID="20"
IOT_VID="30"
GUEST_SSID="HomeWiFi-Guest"
GUEST_KEY="change-this-guest-key"
IOT_SSID="HomeWiFi-IoT"
IOT_KEY="change-this-iot-key"
RADIO="radio0"                  # which radio carries the extra SSIDs
# --------------------

set -e

# Main LAN is VLAN 1: untagged on every port, PVID (the "*") on every port.
uci add network bridge-vlan >/dev/null
uci set network.@bridge-vlan[-1].device='br-lan'
uci set network.@bridge-vlan[-1].vlan='1'
for p in $LAN_PORTS; do
	uci add_list "network.@bridge-vlan[-1].ports=$p:u*"
done

# Guest and IoT VLANs: tagged on the uplink only. Wi-Fi joins them by network name.
for vid in "$GUEST_VID" "$IOT_VID"; do
	uci add network bridge-vlan >/dev/null
	uci set network.@bridge-vlan[-1].device='br-lan'
	uci set network.@bridge-vlan[-1].vlan="$vid"
	uci add_list "network.@bridge-vlan[-1].ports=$UPLINK:t"
done

# The management interface now rides VLAN 1 of the bridge.
uci set network.lan.device='br-lan.1'

# proto none: no IP, no DHCP, no firewall zone for these networks.
uci set network.guest='interface'
uci set network.guest.proto='none'
uci set network.guest.device="br-lan.$GUEST_VID"
uci set network.iot='interface'
uci set network.iot.proto='none'
uci set network.iot.device="br-lan.$IOT_VID"

# Extra SSIDs. isolate=1 stops guest clients talking to each other.
uci set wireless.guest='wifi-iface'
uci set wireless.guest.device="$RADIO"
uci set wireless.guest.mode='ap'
uci set wireless.guest.network='guest'
uci set wireless.guest.ssid="$GUEST_SSID"
uci set wireless.guest.encryption='psk2'
uci set wireless.guest.key="$GUEST_KEY"
uci set wireless.guest.isolate='1'

uci set wireless.iot='wifi-iface'
uci set wireless.iot.device="$RADIO"
uci set wireless.iot.mode='ap'
uci set wireless.iot.network='iot'
uci set wireless.iot.ssid="$IOT_SSID"
uci set wireless.iot.encryption='psk2'
uci set wireless.iot.key="$IOT_KEY"

uci commit network
uci commit wireless
echo "Committed. Make sure the main router tags VLANs $GUEST_VID and $IOT_VID toward the AP, then reboot."
