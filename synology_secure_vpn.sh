#!/bin/bash

############################################
# Make it work on Synology :
# 
#    1. Install Synology Bootstrap : http://forum.synology.com/wiki/index.php/How_to_Install_Bootstrap
#    2. Install new busybox : ipkg install busybox
#    3. 
#
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

		echo "Allow access to certains ports without VPN"
		iptables -A INPUT -i eth0 -p tcp -m multiport --dports 22,5225 -m state --state NEW,ESTABLISHED -j ACCEPT
		iptables -A OUTPUT -o eth0 -p tcp -m multiport --sports 22,5225 -m state --state ESTABLISHED -j ACCEPT

		echo "Drop anything else..."
		iptables -A INPUT -j DROP
		iptables -A OUTPUT -j DROP

		echo ""
		#busybox ip route add default table 100 via 192.168.1.1

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