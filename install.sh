#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $DIR/config/config.sh

# ------------------------------------------------
# Generate login.conf file
# ------------------------------------------------
	echo "$VPN_USERNAME
	$VPN_PASSWORD" > $DIR/config/login.conf

# ------------------------------------------------
# Create file who will start VPN and add iptable
# rules when network goes up.
# Only if no "non-persistent" parameter was passed 
# to script.
# ------------------------------------------------
	if [ "$1" != "non-persistent" ]; then
		cat >> /etc/network/if-up.d/secure-vpn << EOF
#!/bin/bash

$DIR/secure-vpn.sh start
EOF

		chmod +x /etc/network/if-up.d/secure-vpn
	fi

# ------------------------------------------------
# Generate good paths for OpenVPN client config
# ------------------------------------------------
	# Get line where the fun starts
	startLine=$(awk '$0 ~ str{print NR FS b}{b=$0}' str="### CUSTOM PATHS ###" $DIR/config/client.ovpn)

	# Keep only first part of the file (remove "custom" options at the end)
	head -n $startLine $DIR/config/client.ovpn > $DIR/config/client.ovpn.tmp
	mv $DIR/config/client.ovpn.tmp $DIR/config/client.ovpn

	# Add \n at the end of the file only if it doesn't already end in a newline
	sed -i -e '$a\' $DIR/config/client.ovpn

	# Write paths config to file
	echo "auth-user-pass $DIR/config/login.conf" >> $DIR/config/client.ovpn
	echo "route-up $DIR/scripts/vpn_up.sh" >> $DIR/config/client.ovpn
	echo "" >> $DIR/config/client.ovpn
	echo "### CUSTOM OPTIONS ###" >> $DIR/config/client.ovpn

exit 0