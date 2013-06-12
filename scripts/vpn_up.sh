#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $DIR/../config/config.sh

# Delete table 100 and flush all existing rules
ip route flush table 100
ip route flush cache
iptables -t mangle -F PREROUTING

# Table 100 will route all traffic with mark 1 to WAN (no VPN)
ip route add default table 100 via $WAN_GATEWAY dev $WAN_INTERFACE
ip rule add fwmark 1 table 100
ip route flush cache

# Default behavious : all traffic via VPN
#iptables -t mangle -A PREROUTING -j MARK --set-mark 0

for port in "$OPEN_PORTS"; do
	echo "add port $port" >> $DIR/../vpndaemon.log
	iptables -t mangle -A PREROUTING -p tcp --dport $port -j MARK --set-mark 1
done