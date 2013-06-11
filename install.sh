#!/bin/bash

source ./config/config.sh

# Login conf
echo "$VPN_USERNAME
$VPN_PASSWORD" > ./config/login.conf

# ------------------------------------------------
# Add ports config to Raspberry OpenVPN up file
# ------------------------------------------------

# Get line where the fun starts
startLine=$(awk '$0 ~ str{print NR FS b}{b=$0}' str="#### PORTS CONFIG ####" ./scripts/raspberry_vpn_up.sh)

# Keep only first part of the file (remove ports rules at the end)
head -n $startLine ./scripts/raspberry_vpn_up.sh > ./scripts/raspberry_vpn_up_tmp.sh
mv ./scripts/raspberry_vpn_up_tmp.sh ./scripts/raspberry_vpn_up.sh

# Add all ports to the file
for port in "$RASPBERRY_PORTS $SYNOLOGY_PORTS"; do
	# Add \n at the end of the file only if it doesn't already end in a newline
	sed -i -e '$a\' ./scripts/raspberry_vpn_up.sh

	echo "iptables -t mangle -A PREROUTING -p tcp --dport $port -j MARK --set-mark 1" >> ./scripts/raspberry_vpn_up.sh
done

exit 0