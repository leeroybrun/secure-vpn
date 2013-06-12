#!/bin/bash

# ------------------------------------------------
# Load config file
# ------------------------------------------------
source ./config/config.sh

LOCAL_IP=$(hostname -I | tr -d ' ')

# ------------------------------------------------
# Main
# ------------------------------------------------
function main {
	case "$1" in
		start)
			iptablesFlush

			iptablesRules

			startVPN

			# If it doesn't work, reboot after 20 minutes
			sleep 1200
			reboot

			exit 0
		;;

		stop)
			iptablesFlush

			stopVPN

			exit 0
		;;

		*)
			echo "Usage : $0 {start|stop}"
			exit 1
		;;
	esac
}

# ------------------------------------------------
# Flush iptables rules and reset default policy
# ------------------------------------------------
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

# ------------------------------------------------
# Add iptables rules
# ------------------------------------------------
function iptablesRules
{
	echo "General iptables rules"

	iptables -P INPUT DROP
	iptables -P FORWARD DROP
	iptables -P OUTPUT DROP

	# Accept packets through VPN
	iptables -A INPUT -i tun+ -j ACCEPT
	iptables -A OUTPUT -o tun+ -j ACCEPT

	# Accept local connections
	iptables -A INPUT -i lo -j ACCEPT
	iptables -A OUTPUT -o lo -j ACCEPT

	# Accept connections from/to VPN servers
	while read line; do
		if [[ "$line" =~ ^[a-zA-Z0-9]+\ [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\ [0-9]+$ ]]; then
			read srvName srvIp srvPort <<< $line

			echo "Open connections from/to $srvName : $srvIp"

			if [ "$srvIp" != "" ]; then
				iptables -A INPUT -s "$srvIp" -j ACCEPT
				iptables -A OUTPUT -d "$srvIp" -j ACCEPT
			fi
		fi
	done <./config/servers.conf

	# Accept connections from/to local network
	#iptables -A INPUT -s "$LOCAL_NETWORK" -j ACCEPT
	#iptables -A OUTPUT -d "$LOCAL_NETWORK" -j ACCEPT

	# Disable Reverse Path Filtering on all network interfaces
	for i in /proc/sys/net/ipv4/conf/*/rp_filter ; do
		echo 0 > $i
	done

	# Open Raspberry ports
	for port in $OPEN_PORTS; do
		iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
		iptables -A OUTPUT -p tcp --sport "$port" -j ACCEPT
	done
}

# ------------------------------------------------
# Start the VPN daemon
# ------------------------------------------------
function startVPN
{
	echo "Start VPN daemon"

	daemonPid=$(cat /tmp/vpndaemon.pid 2> /dev/null)
	if [ "$daemonPid" != "" ]; then
		if ps ax | grep -v grep | grep "$daemonPid" > /dev/null; then
			echo "VPN daemon already running..."
			exit 2
		fi
	fi

	nohup bash ./scripts/vpndaemon.sh > ./vpndaemon.log 2>&1 &
	echo $! > /tmp/vpndaemon.pid
}

# ------------------------------------------------
# Stop the VPN daemon
# ------------------------------------------------
function stopVPN
{
	echo "Stop VPN daemon"

	killall openvpn

	daemonPid=$(cat ./vpndaemon.pid)
	kill -p $daemonPid

	rm -f /tmp/vpndaemon.pid
}

# Call the main function
main "$1"