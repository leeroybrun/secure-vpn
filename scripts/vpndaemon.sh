#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function getStatus {
	ifconfig | grep "$1" && return 1
	return 0
}

while :
do
	getStatus tun0
	if [[ $? == 0 ]]; then
		echo "OpenVPN not connected ! Reconnecting..."
		openvpn --config $DIR/../config/client.ovpn

		# Wait 1 minute before next check
		sleep 60
	else
		# Already connected, next check in 5 minutes
		sleep 300
	fi
done