#!/bin/bash

# CONFIG
source ./config/config.sh

LOCAL_IP=$(hostname -I | tr -d ' ')

# MAIN
function main {
	case "$1" in
		start)
			iptablesFlush

			iptablesDefault

			if [[ "$LOCAL_IP" = "$SYNOLOGY_IP" ]]; then
				synologyRules
			elif [[ "$LOCAL_IP" = "$RASPBERRY_IP" ]]; then
				raspberryRules
			fi

			iptablesGeneralRules

			startVPN

			# If it doesn't work, reboot after 2 minutes
			sleep 120
			reboot

			exit 0
		;;

		stop)
			iptablesFlush

			exit 0
		;;

		*)
			echo "Usage : $0 {start|stop}"
			exit 1
		;;
	esac
}

# Flush iptables rules
function iptablesFlush
{
	echo "Flush iptables"
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -F
	iptables -X
	iptables -t nat -F
	iptables -t nat -X
	iptables -t mangle -F
	iptables -t mangle -X
}

# Set default chain policies
function iptablesDefault
{
	iptables -P INPUT DROP
	iptables -P FORWARD DROP
	iptables -P OUTPUT DROP
}

# Add default rules, block all traffic except local & VPN
function iptablesGeneralRules
{
	echo "General iptables rules"

	# Accept packets through VPN
	iptables -A INPUT -i tun+ -j ACCEPT
	iptables -A OUTPUT -o tun+ -j ACCEPT

	# Accept local connections
	#iptables -A INPUT -s 127.0.0.1 -j ACCEPT
	#iptables -A OUTPUT -d 127.0.0.1 -j ACCEPT
	iptables -A INPUT -i lo -j ACCEPT
	iptables -A OUTPUT -o lo -j ACCEPT

	# Accept connections from/to VPN servers
	iptables -A INPUT -s "$VPN_SERVER_IP" -j ACCEPT
	iptables -A OUTPUT -d "$VPN_SERVER_IP" -j ACCEPT

	# Accept connections from/to local network
	# TODO : auto detect local network
	iptables -A INPUT -s "$LOCAL_NETWORK" -j ACCEPT
	iptables -A OUTPUT -d "$LOCAL_NETWORK" -j ACCEPT

	# Drop anything else...
	#iptables -A INPUT -j DROP
	#iptables -A OUTPUT -j DROP
}

# Specific rules for Raspberry Pi
# Route specific traffic without VPN & forward some packets to Synology
function raspberryRules
{
	echo "Apply Raspberry Pi rules"

	# Disable Reverse Path Filtering on all network interfaces
	for i in /proc/sys/net/ipv4/conf/*/rp_filter ; do
		echo 0 > $i
	done

	# Enable IP forwarding
	echo "1" > /proc/sys/net/ipv4/ip_forward

	# Redirect traffic from certains ports to Synology
	# http://www.debuntu.org/how-to-redirecting-network-traffic-to-a-new-ip-using-iptables/
	# http://www.ridinglinux.org/2008/05/21/simple-port-forwarding-with-iptables-in-linux/
	iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
	for port in $SYNOLOGY_PORTS; do
		iptables -I FORWARD -p tcp -d "$SYNOLOGY_IP" --dport "$port" -j ACCEPT
		iptables -I FORWARD -p tcp -s "$SYNOLOGY_IP" --sport "$port" -j ACCEPT
		iptables -t nat -A PREROUTING -p tcp --dport "$port" -j DNAT --to-destination "$SYNOLOGY_IP:$port"

		iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
		iptables -A OUTPUT -p tcp --sport "$port" -j ACCEPT
	done

	# Open Raspberry ports
	for port in $RASPBERRY_PORTS; do
		iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
		iptables -A OUTPUT -p tcp --sport "$port" -j ACCEPT
	done
}

# Specific rules for Synology
function synologyRules
{
	echo "Apply Synology Rules"
}

# Start VPN daemon
function startVPN
{
	echo "Start VPN daemon"

	daemonPid=$(cat ./vpndaemon.pid 2> /dev/null)
	if [ "$daemonPid" != "" ]; then
		if ps ax | grep -v grep | grep "$daemonPid" > /dev/null; then
			echo "VPN daemon already running..."
			exit 2
		fi
	fi

	nohup bash ./scripts/vpndaemon.sh > ./vpndaemon.log 2>&1 &
	echo $! > ./vpndaemon.pid
}

# Stop VPN daemon
function stopVPN
{
	echo "Stop VPN daemon"

	iptablesFlush
	killall openvpn

	daemonPid=$(cat ./vpndaemon.pid)
	kill -p $daemonPid
}

# Call the main function
main "$1"