#!/bin/sh
# Turn a default OpenWrt 25.12 router into a bridged ("dumb") access point.
# Run it on the AP over SSH, from a PC cabled to an AP LAN port (not WAN).
# It commits the config but does NOT restart anything. Reboot when it is done.

# ---- edit these ----
AP_IP="192.168.1.2"          # free address on the main LAN, outside its DHCP pool
PREFIX="24"                  # subnet prefix length of the main LAN
GATEWAY="192.168.1.1"        # main router
DNS="192.168.1.1"            # main router
SSID="HomeWiFi"
KEY="change-this-passphrase" # 8 to 63 characters
COUNTRY="US"                 # two-letter code for your country
ENCRYPTION="psk2"            # psk2 = WPA2-PSK, sae-mixed = WPA2/WPA3
ADD_WAN_PORT="1"             # 1 = make the WAN port a normal LAN port
AP_IPV6="0"                  # 1 = give the AP its own address via SLAAC/DHCPv6
# --------------------

set -e

# 1. Static address, gateway, DNS. 25.12 defaults to a list ipaddr, so delete first.
uci -q delete network.lan.ipaddr || true
uci -q delete network.lan.netmask || true
uci set network.lan.proto='static'
uci add_list network.lan.ipaddr="$AP_IP/$PREFIX"
uci set network.lan.gateway="$GATEWAY"
uci -q delete network.lan.dns || true
uci add_list network.lan.dns="$DNS"
# The AP must not hand out an IPv6 prefix of its own.
uci -q delete network.lan.ip6assign || true

# 2. Optional IPv6 address for the AP itself (no prefix requested).
if [ "$AP_IPV6" = "1" ]; then
	uci set network.lan6='interface'
	uci set network.lan6.proto='dhcpv6'
	uci set network.lan6.device='@lan'
	uci set network.lan6.reqaddress='try'
	uci set network.lan6.reqprefix='no'
fi

# 3. DHCP and RA off on the LAN. These four lines are the documented way.
uci set dhcp.lan.dhcpv4='disabled'
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.ignore='1'

# 4. WAN port becomes a normal bridge port. Delete wan/wan6 first: a port can
#    live in the bridge or in an interface, not both.
if [ "$ADD_WAN_PORT" = "1" ]; then
	uci -q delete network.wan || true
	uci -q delete network.wan6 || true
	i=0
	while uci -q get "network.@device[$i]" >/dev/null; do
		if [ "$(uci -q get "network.@device[$i].name")" = "br-lan" ]; then
			uci add_list "network.@device[$i].ports"='wan'
			break
		fi
		i=$((i + 1))
	done
fi

# 5. Wi-Fi: country, enable radios, set SSID and key on every default AP section.
for radio in $(uci show wireless | sed -n "s/^wireless\.\(radio[0-9]*\)=wifi-device$/\1/p"); do
	uci set "wireless.$radio.country=$COUNTRY"
	uci set "wireless.$radio.disabled=0"
	uci set "wireless.default_$radio.network=lan"
	uci set "wireless.default_$radio.mode=ap"
	uci set "wireless.default_$radio.ssid=$SSID"
	uci set "wireless.default_$radio.encryption=$ENCRYPTION"
	uci set "wireless.default_$radio.key=$KEY"
done

uci commit network
uci commit dhcp
uci commit wireless
echo "Committed. Check with: uci show network.lan; uci show dhcp.lan"
echo "Then run: reboot   (move the uplink cable to a LAN port first)"
