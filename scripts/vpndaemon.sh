#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ "$1" =~ ^[0-9]+$ ]]; then
	currServerLine=$1
else
	currServerLine=0
fi

currServer=""
nbServers=0
retry=0

# ------------------------------------------------
# Get status of VPN connection
# ------------------------------------------------
function getStatus {
	ifconfig | grep "$1" && return 1
	return 0
}

# ------------------------------------------------
# Get next server from config file
# ------------------------------------------------
function getNextServer {
	# Get number of servers in config
	nbServers=$(wc -l < $DIR/../config/servers.conf)

	currServerLine=$[currServerLine + 1]

	# Current server doesn't exist (number gt nbServers)
	if [ $currServerLine -gt $nbServers ]; then
		currServerLine=1
	fi

	# Get new server line from config
	newServer=$(sed -n "$[currServerLine]p" < $DIR/../config/servers.conf)

	# If new server line is correctly formated, parse server infos
	if [[ "$newServer" =~ SRV_LINE_FORMAT ]]; then
		currServer=$newServer
		read srvName srvIp srvPort srvProto <<< $currServer
	# Else, get next server
	else
		getNextServer
	fi
}

# ------------------------------------------------
# Write new server config to OpenVPN config file
# ------------------------------------------------
function writeOvpnConfig {
	# Get line where the fun starts
	startLine=$(awk '$0 ~ str{print NR FS b}{b=$0}' str="### CUSTOM OPTIONS ##" $DIR/../config/client.ovpn)

	# Keep only first part of the file (remove "custom" options at the end)
	head -n $startLine $DIR/../config/client.ovpn > $DIR/../config/client.ovpn.tmp
	mv $DIR/../config/client.ovpn.tmp $DIR/../config/client.ovpn

	# Add \n at the end of the file only if it doesn't already end in a newline
	sed -i -e '$a\' $DIR/../config/client.ovpn

	# Write server config to file
	echo "proto $srvProto" >> $DIR/../config/client.ovpn
	echo "remote $srvIp $srvPort" >> $DIR/../config/client.ovpn
	echo "ca $DIR/../config/certs/$srvName.crt" >> $DIR/../config/client.ovpn
}

# ------------------------------------------------
# Get random server & write config
# ------------------------------------------------
getNextServer
writeOvpnConfig

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

		# Tried 3 times connecting to server ? Get new one from config.
		if [ "$retry" -eq "3" ]; then
			echo "Tried 3 times connecting to $srvName. Get new random server..."

			getNextServer

			echo "New server : $currServer"

			echo "Write OpenVPN config file..."

			writeOvpnConfig

			retry=0
		fi

		echo "Connection to server..."

		openvpn --config $DIR/../config/client.ovpn

		retry=$[retry + 1]

		# Wait 1 minute before next check
		sleep 60
	else
		# Already connected, next check in 5 minutes
		sleep 300
	fi
done