#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $DIR/../config/config.sh

echo 1 > /proc/sys/net/ipv4/ip_forward

# Delete table 100 and flush all existing rules
ip route flush table 100
ip route flush cache
iptables -t mangle -F PREROUTING

# Table 100 will route all traffic with mark 1 to WAN (no VPN)
ip route add default via $WAN_GATEWAY dev $WAN_INTERFACE table 100
ip route add table 100 to 91.121.166.0/24 dev eth0
ip rule add from all fwmark 1 table 100

# https://forum.linode.com/viewtopic.php?p=50114&sid=b440414422596bb7dbc96cf7c9ee511f#p50114
ip rule add from 91.121.166.103 table 100
ip route add table 100 to 91.121.166.0/24 dev eth0
ip route add table 128 default via 91.121.166.254

# Default behavious : all traffic via VPN
#iptables -t mangle -A PREROUTING -j MARK --set-mark 0

for port in "$OPEN_PORTS"; do
	echo "add port $port"
	iptables -A PREROUTING -t mangle -p tcp --dport $port -j MARK --set-mark 1
	iptables -A PREROUTING -t mangle -i eth0 -p tcp --dport $port -j MARK --set-mark 1

	iptables -A PREROUTING -t mangle -p tcp --sport $port -j MARK --set-mark 1
	iptables -A PREROUTING -t mangle -i eth0 -p tcp --sport $port -j MARK --set-mark 1
done

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE

iptables -L >> $DIR/../iptables.log 
ip route >> $DIR/../iptables.log 
ip route show table 100 >> $DIR/../iptables.log 
ip rule show >> $DIR/../iptables.log 