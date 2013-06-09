#!/bin/bash

# TorGuard Raspberry : http://torguard.net/knowledgebase.php?action=displayarticle&id=90

SYNOLOGY_IP="192.168.1.80"
SYNOLOGY_PORT="1234"
RASPBERRY_SSH_PORT="1234"
LOCAL_NETWORK="192.168.1.0/24"
WAN_INTERFACE="eth0"
WAN_GATEWAY="192.168.1.1"

case "$1" in
	start)
		echo "Flush iptables"
		iptables -F
		iptables -X

		echo "Set default chain policies"
		iptables -P INPUT DROP
		iptables -P FORWARD DROP
		iptables -P OUTPUT DROP

		echo "Accept packets through VPN"
		iptables -A INPUT -i tun+ -j ACCEPT
		iptables -A OUTPUT -o tun+ -j ACCEPT

		echo "Accept local connections"
		#iptables -A INPUT -s 127.0.0.1 -j ACCEPT
		#iptables -A OUTPUT -d 127.0.0.1 -j ACCEPT
		iptables -A INPUT -i lo -j ACCEPT
		iptables -A OUTPUT -o lo -j ACCEPT

		echo "Accept connections from/to VPN servers"
		iptables -A INPUT -s 141.255.160.226 -j ACCEPT
		iptables -A OUTPUT -d 141.255.160.226 -j ACCEPT

		echo "Accept connections from/to local network"
		# TODO : auto detect local network
		iptables -A INPUT -s "$LOCAL_NETWORK" -j ACCEPT
		iptables -A OUTPUT -d "$LOCAL_NETWORK" -j ACCEPT

		echo "Allow access to certains ports without VPN"
		iptables -A INPUT -i "$WAN_INTERFACE" -p tcp -m multiport --dports "$RASPBERRY_SSH_PORT,$SYNOLOGY_PORT" -m state --state NEW,ESTABLISHED -j ACCEPT
		iptables -A OUTPUT -o "$WAN_INTERFACE" -p tcp -m multiport --sports "$RASPBERRY_SSH_PORT,$SYNOLOGY_PORT" -m state --state ESTABLISHED -j ACCEPT

		echo "Drop anything else..."
		iptables -A INPUT -j DROP
		iptables -A OUTPUT -j DROP

		echo "Rules for redirecting certains ports traffic"
		ip route add default table 100 via $WAN_GATEWAY dev $WAN_INTERFACE
		ip rule add fwmark 1 table 100
		ip route flush cache
		iptables -t mangle -I PREROUTING -p tcp --dport "$RASPBERRY_SSH_PORT,$SYNOLOGY_PORT" -j MARK --set-mark 1

		echo "Enable IP forwarding"
		echo "1" > /proc/sys/net/ipv4/ip_forward

		echo "Redirect traffic from certains ports to Synology"
		# http://www.debuntu.org/how-to-redirecting-network-traffic-to-a-new-ip-using-iptables/
		iptables -t nat -A PREROUTING -p tcp –dport "$SYNOLOGY_PORT" -j DNAT –to-destination "$SYNOLOGY_IP:$SYNOLOGY_PORT"
		iptables -t nat -A POSTROUTING -j MASQUERADE

		echo "For testing purpose, reset iptables after 20 seconds"
		sleep 20
		iptables -F
		iptables -X


	;;

	stop)
		iptables -F
		iptables -X
	;;

	*)
		echo "Usage : $0 {start|stop}"
	;;
esac