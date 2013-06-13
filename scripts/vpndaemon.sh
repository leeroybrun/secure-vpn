#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# ------------------------------------------------
# Get status of VPN connection
# ------------------------------------------------
function getStatus {
	ifconfig | grep "$1" && return 1
	return 0
}

# ------------------------------------------------
# Infinite loop for daemon - check if VPN is up
# and restart it if needed. If can't connect to
# VPN server after 3 retry, load new server config.
# ------------------------------------------------
while :
do
	getStatus tun0
	if [[ $? == 0 ]]; then
		date
		echo "OpenVPN not connected !"

		echo "Connection to server..."

		openvpn --config $DIR/../config/client.ovpn

		# Wait 1 minute before next check
		sleep 60
	else
		# Already connected, next check in 5 minutes
		sleep 300
	fi
done