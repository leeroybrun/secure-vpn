#!/bin/bash

############################################
# 

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
		iptables -A INPUT -s 192.168.1.0/24 -j ACCEPT
		iptables -A OUTPUT -d 192.168.1.0/24 -j ACCEPT

		echo "Drop anything else..."
		iptables -A INPUT -j DROP
		iptables -A OUTPUT -j DROP

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