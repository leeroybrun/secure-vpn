#!/bin/bash

# TorGuard Raspberry : http://torguard.net/knowledgebase.php?action=displayarticle&id=90

# TODO : 
#   - knock knock on ports
#   - automatically switch betweens servers if we cannot connect to one

#########################################
#                CONFIG                 #
#########################################

SYNOLOGY_IP="192.168.1.80"
SYNOLOGY_PORT="1234"

RASPBERRY_IP="192.168.1.49"
RASPBERRY_PORTS="1234"

LOCAL_NETWORK="192.168.1.0/24"
WAN_INTERFACE="eth0"
WAN_GATEWAY="192.168.1.1"

VPN_USERNAME=""
VPN_PASSWORD=""
VPN_SERVER_IP="94.102.56.181"

##########################################
#         DON'T EDIT LINES BELOW         #
##########################################

LOCAL_IP=$(hostname -I | tr -d ' ')

# Main
function main {
	case "$1" in
		start)
			writeFiles

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
	echo "Apply Raspberry Pi Rules"

	# Disable Reverse Path Filtering on all network interfaces
	for i in /proc/sys/net/ipv4/conf/*/rp_filter ; do
		echo 0 > $i
	done

	# Enable IP forwarding
	echo "1" > /proc/sys/net/ipv4/ip_forward

	# Redirect traffic from certains ports to Synology
	# TODO : loop over all ports dynamically
	# http://www.debuntu.org/how-to-redirecting-network-traffic-to-a-new-ip-using-iptables/
	# http://www.ridinglinux.org/2008/05/21/simple-port-forwarding-with-iptables-in-linux/
	iptables -I FORWARD -p tcp -d "$SYNOLOGY_IP" --dport "$SYNOLOGY_PORT" -j ACCEPT
	iptables -I FORWARD -p tcp -s "$SYNOLOGY_IP" --sport "$SYNOLOGY_PORT" -j ACCEPT
	iptables -t nat -A PREROUTING -p tcp --dport "$SYNOLOGY_PORT" -j DNAT --to-destination "$SYNOLOGY_IP:$SYNOLOGY_PORT"
	iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

	# Open SSH & Synology ports on iptables
	# TODO : loop over all ports dynamically
	iptables -A INPUT -p tcp --dport 22 -j ACCEPT
	iptables -A INPUT -p tcp --dport 16364 -j ACCEPT
	iptables -A INPUT -p tcp --dport 5225 -j ACCEPT
	iptables -A OUTPUT -p tcp --sport 22 -j ACCEPT
	iptables -A OUTPUT -p tcp --sport 16364 -j ACCEPT
	iptables -A OUTPUT -p tcp --sport 5225 -j ACCEPT
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

	daemonPid=$(cat /tmp/vpnfiles/vpndaemon.pid 2> /dev/null)
	if [ "$daemonPid" != "" ]; then
		if ps ax | grep -v grep | grep "$daemonPid" > /dev/null; then
			echo "VPN daemon already running..."
			exit 2
		fi
	fi

	sudo nohup bash /tmp/vpnfiles/vpndaemon.sh > /tmp/vpnfiles/vpndaemon.log 2>&1 &
	echo $! > /tmp/vpnfiles/vpndaemon.pid
}

# Stop VPN daemon
function stopVPN
{
	echo "Stop VPN daemon"

	iptablesFlush
	killall openvpn

	daemonPid=$(cat /tmp/vpnfiles/vpndaemon.pid)
	kill -p $daemonPid
}

# Write OpenVPN files
#   - login conf
#   - vpndaemon script
#   - openvpn conf
#   - vpn certificate
function writeFiles
{
	rm -rf /tmp/vpnfiles/
	mkdir /tmp/vpnfiles/

	# Login conf
	echo "$VPN_USERNAME
	$VPN_PASSWORD" > /tmp/vpnfiles/login.conf

	# VPN daemon script
	cat >> /tmp/vpnfiles/vpndaemon.sh << EOF
		#!/bin/bash
		
		function getStatus {
			ifconfig | grep "\$1" && return 1
			return 0
		}

		while :
		do
			getStatus tun0
			if [[ \$? == 0 ]]; then
				echo "OpenVPN not connected ! Reconnecting..."
				openvpn --config /tmp/vpnfiles/client.ovpn

				# Wait 1 minute before next check
				sleep 60
			else
				# Already connected, next check in 5 minutes
				sleep 300
			fi
		done
EOF
	chmod +x /tmp/vpnfiles/vpndaemon.sh

	cat >> /tmp/vpnfiles/raspberry_vpn_up.sh << EOF
		#!/bin/bash

		# Delete table 100 and flush all existing rules
		ip route flush table 100
		ip route flush cache
		iptables -t mangle -F PREROUTING

		# Table 100 will route all traffic with mark 1 to WAN (no VPN)
		ip route add default table 100 via $WAN_GATEWAY dev $WAN_INTERFACE
		ip rule add fwmark 1 table 100
		ip route flush cache

		# Default behavious : all traffic via VPN
		#iptables -t mangle -A PREROUTING -j MARK --set-mark 0

		# SSH and Synology ports bypass VPN
		#iptables -t mangle -A PREROUTING -p tcp -m multiport --dport "$RASPBERRY_PORTS,$SYNOLOGY_PORT" -j MARK --set-mark 1

		iptables -t mangle -A PREROUTING -p tcp --dport 22 -j MARK --set-mark 1
        iptables -t mangle -A PREROUTING -p tcp --dport 16364 -j MARK --set-mark 1
        iptables -t mangle -A PREROUTING -p tcp --dport 5225 -j MARK --set-mark 1
EOF
	chmod +x /tmp/vpnfiles/raspberry_vpn_up.sh

	# OpenVPN client config
	cat >> /tmp/vpnfiles/client.ovpn << EOF
client
dev tun
proto udp
remote 94.102.56.181 443
resolv-retry infinite
nobind
tun-mtu 1500
tun-mtu-extra 32
mssfix 1450
persist-key
persist-tun
ca /tmp/vpnfiles/ca.crt
auth-user-pass /tmp/vpnfiles/login.conf
comp-lzo
verb 3
redirect-gateway def1
user nobody
group nogroup
script-security 2
up /tmp/vpnfiles/raspberry_vpn_up.sh
EOF

	# OpenVPN server certificate
	cat >> /tmp/vpnfiles/ca.crt << EOF
-----BEGIN CERTIFICATE-----
MIID4DCCA0mgAwIBAgIJAOMRjAPVlRixMA0GCSqGSIb3DQEBBQUAMIGnMQswCQYD
VQQGEwJVUzELMAkGA1UECBMCQ0ExFTATBgNVBAcTDFNhbkZyYW5jaXNjbzEVMBMG
A1UEChMMRm9ydC1GdW5zdG9uMREwDwYDVQQLEwhjaGFuZ2VtZTEWMBQGA1UEAxMN
OTQuMTAyLjU2LjE4MTERMA8GA1UEKRMIY2hhbmdlbWUxHzAdBgkqhkiG9w0BCQEW
EG1haWxAaG9zdC5kb21haW4wHhcNMTMwMzIyMjI0NTAzWhcNMjMwMzIwMjI0NTAz
WjCBpzELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAkNBMRUwEwYDVQQHEwxTYW5GcmFu
Y2lzY28xFTATBgNVBAoTDEZvcnQtRnVuc3RvbjERMA8GA1UECxMIY2hhbmdlbWUx
FjAUBgNVBAMTDTk0LjEwMi41Ni4xODExETAPBgNVBCkTCGNoYW5nZW1lMR8wHQYJ
KoZIhvcNAQkBFhBtYWlsQGhvc3QuZG9tYWluMIGfMA0GCSqGSIb3DQEBAQUAA4GN
ADCBiQKBgQDfGK7Q1ZljPs2D1gzT/KQq6+I/uYcK0+q4ZoIrVSUqZ6oqkMhwQyae
/NipkUaQHUybAEOjeKA00W8q9uhNYjiltid/xGqJtvbq5y3qrgCWsx5BgGB2NBmK
trU6UBQuJsbtMyYO7auLF8iWiUR0j1CUx1tCSJoXzfxD++LwthWznQIDAQABo4IB
EDCCAQwwHQYDVR0OBBYEFDSKr+GgSQZpHMcSlXXmEDSoZRVdMIHcBgNVHSMEgdQw
gdGAFDSKr+GgSQZpHMcSlXXmEDSoZRVdoYGtpIGqMIGnMQswCQYDVQQGEwJVUzEL
MAkGA1UECBMCQ0ExFTATBgNVBAcTDFNhbkZyYW5jaXNjbzEVMBMGA1UEChMMRm9y
dC1GdW5zdG9uMREwDwYDVQQLEwhjaGFuZ2VtZTEWMBQGA1UEAxMNOTQuMTAyLjU2
LjE4MTERMA8GA1UEKRMIY2hhbmdlbWUxHzAdBgkqhkiG9w0BCQEWEG1haWxAaG9z
dC5kb21haW6CCQDjEYwD1ZUYsTAMBgNVHRMEBTADAQH/MA0GCSqGSIb3DQEBBQUA
A4GBABcMvZcG2atO8MW5qpG4qculNE4tJyFQB+TDDdoLUWJYHSw0j5kdYX27Ff9l
Ba2RYagTlp3ArqIcyJnlz7kJDXrBxb3twKnZWg7moTBXRgJSPG75t81UO393wZdo
kzj3mD7BZoGmeMrqhmYBkiukeOags3KCTfJ9yozyqd3V0UzF
-----END CERTIFICATE-----
EOF

}

# Call the main function
main "$1"