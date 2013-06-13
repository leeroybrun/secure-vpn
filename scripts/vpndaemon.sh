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
# Write all servers config to OpenVPN config file
# ------------------------------------------------
function writeAllServersConf {
	emptyServersConfig

	# Declare associative array
	declare -A loadedCerts

	# Write all servers
	while read server; do
		read srvName srvIp srvPort srvProto <<< $server

		echo "remote $srvIp $srvPort" >> $DIR/../config/client.ovpn

		# Only include cert if not already done
		if [[ ${loadedCerts[$srvName]} != 1 ]]; then
			loadedCerts[$srvName]=1
			echo "ca $DIR/../config/certs/$srvName.crt" >> $DIR/../config/client.ovpn
		fi
	done < $DIR/../config/servers.conf
}

# ------------------------------------------------
# Write only one server config to OpenVPN config file
# ------------------------------------------------
function writeOneServerConf {
	emptyServersConfig

	# Get number of servers in config
	nbServers=$(wc -l < $DIR/../config/servers.conf)

	currServerLine=$1

	# Current server doesn't exist (number gt nbServers), exit
	if [ $currServerLine -gt $nbServers ]; then
		exit 1
	fi

	# Get server line from config
	server=$(sed -n "$[currServerLine]p" < $DIR/../config/servers.conf)

	# If server line is correctly formated, parse server infos
	if [[ "$server" =~ $SRV_LINE_FORMAT ]]; then
		read srvName srvIp srvPort srvProto <<< $server

		# Write server config to file
		echo "proto $srvProto" >> $DIR/../config/client.ovpn
		echo "remote $srvIp $srvPort" >> $DIR/../config/client.ovpn
		echo "ca $DIR/../config/certs/$srvName.crt" >> $DIR/../config/client.ovpn
	# Else, exit
	else
		exit 1
	fi
}

# ------------------------------------------------
# Empty the server config in OpenVPN config file
# ------------------------------------------------
function emptyServersConfig {
	# Get line where the fun starts
	startLine=$(awk '$0 ~ str{print NR FS b}{b=$0}' str="### CUSTOM OPTIONS ##" $DIR/../config/client.ovpn)

	# Keep only first part of the file (remove "custom" options at the end)
	head -n $startLine $DIR/../config/client.ovpn > $DIR/../config/client.ovpn.tmp
	mv $DIR/../config/client.ovpn.tmp $DIR/../config/client.ovpn

	# Add \n at the end of the file only if it doesn't already end in a newline
	sed -i -e '$a\' $DIR/../config/client.ovpn
}

# ------------------------------------------------
# If server line provided, load only this one.
# Else, load all servers.
# ------------------------------------------------
if [[ "$1" =~ ^[0-9]+$ ]]; then
	writeOneServerConf "$1"
else
	writeAllServersConf
fi

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