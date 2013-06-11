#!/bin/bash

source ./config/config.sh

# Login conf
echo "$VPN_USERNAME
$VPN_PASSWORD" > ./config/login.conf

# Add ports config to Raspberry OpenVPN up file
startLine=$(awk '$0 ~ str{print NR FS b}{b=$0}' str="#### PORTS CONFIG ####" ./scripts/raspberry_vpn_up.sh)

echo "$startLine"

head -n $startLine ./scripts/raspberry_vpn_up.sh > ./scripts/raspberry_vpn_up_tmp.sh
mv ./scripts/raspberry_vpn_up_tmp.sh ./scripts/raspberry_vpn_up.sh

for port in "$RASPBERRY_PORTS $SYNOLOGY_PORTS"; do
	echo >> ./scripts/raspberry_vpn_up.sh
	echo "iptables -t mangle -A PREROUTING -p tcp --dport $port -j MARK --set-mark 1" >> ./scripts/raspberry_vpn_up.sh
done


chmod +x ./scripts/raspberry_vpn_up.sh

exit 0