#!/bin/sh
# Runs inside the openwrt/rootfs container. UCI only: no netifd, no radio.
set -e
/bin/config_generate
# config_generate has no board.json here, so it makes a lone br-lan with eth0.
# Add the ports and the wan interfaces a real router has, plus a stub radio.
uci delete network.@device[0].ports
for p in lan1 lan2 lan3 lan4; do uci add_list network.@device[0].ports="$p"; done
uci set network.wan=interface; uci set network.wan.device=wan; uci set network.wan.proto=dhcp
uci set network.wan6=interface; uci set network.wan6.device=wan; uci set network.wan6.proto=dhcpv6
uci commit network
cat > /etc/config/wireless <<'WL'
config wifi-device 'radio0'
	option type 'mac80211'
	option channel '36'
	option band '5g'
	option htmode 'HE80'
	option disabled '1'

config wifi-iface 'default_radio0'
	option device 'radio0'
	option network 'lan'
	option mode 'ap'
	option ssid 'OpenWrt'
	option encryption 'none'
WL
echo "##### BEFORE"; uci export network | sed -n '/lan/,$p'
sh /work/dumb-ap.sh
echo "##### AFTER dumb-ap.sh"; uci export network; uci export dhcp | sed -n '/dhcp .lan/,/^$/p'; uci export wireless
UPLINK=lan1 sh /work/vlan-ssids.sh
echo "##### AFTER vlan-ssids.sh"; uci export network; uci export wireless
