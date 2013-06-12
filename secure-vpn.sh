#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# ------------------------------------------------
# Load config file
# ------------------------------------------------
source $DIR/config/config.sh

# ------------------------------------------------
# Main
# ------------------------------------------------
function main {
	case "$1" in
		start)
			iptablesFlush

			iptablesRules

			startVPN

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
		if [[ "$line" =~ ^[a-zA-Z0-9]+\ [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\ [0-9]+\ [a-z]{3}$ ]]; then
			read srvName srvIp srvPort srcProto <<< $line

			echo "Open connections from/to $srvName : $srvIp $srvPort"

			if [ "$srvIp" != "" ]; then
				iptables -A INPUT -s "$srvIp" -j ACCEPT
				iptables -A OUTPUT -d "$srvIp" -j ACCEPT
			fi
		fi
	done < $DIR/config/servers.conf

	# Accept connections from/to local network
	#iptables -A INPUT -s "$LOCAL_NETWORK" -j ACCEPT
	#iptables -A OUTPUT -d "$LOCAL_NETWORK" -j ACCEPT

	# Disable Reverse Path Filtering on all network interfaces
	for i in /proc/sys/net/ipv4/conf/*/rp_filter ; do
		echo 0 > $i
	done

	# Open allowed ports ports
	for port in $OPEN_PORTS; do
		iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
		iptables -A OUTPUT -p tcp --sport "$port" -j ACCEPT
	done
}

# ------------------------------------------------
# Start the VPN daemon
# 	Parameters :
#		$1 -> line number of server to use for VPN
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

	nohup bash $DIR/scripts/vpndaemon.sh "$1" > $DIR/vpndaemon.log 2>&1 &
	echo $! > /tmp/vpndaemon.pid
}

# ------------------------------------------------
# Stop the VPN daemon
# ------------------------------------------------
function stopVPN
{
	echo "Stop VPN daemon"

	pkill openvpn

	daemonPid=$(cat /tmp/vpndaemon.pid)
	kill "$daemonPid"

	rm -f /tmp/vpndaemon.pid
}

# ------------------------------------------------
# Test speeds of different servers in config
# ------------------------------------------------
function testSpeed {
	
}

# Call the main function
main "$1"