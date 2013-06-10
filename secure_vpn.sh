#!/bin/bash

# TorGuard Raspberry : http://torguard.net/knowledgebase.php?action=displayarticle&id=90

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
VPN_SERVER_IP="141.255.160.226"

##########################################
#         DON'T EDIT LINES ABOVE         #
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

			#startVPN

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

	# Delete table 100 and flush all existing rules
	ip route flush table 100
	ip route flush cache
	iptables -t mangle -F PREROUTING

	# Table 100 will route all traffic with mark 1 to WAN (no VPN)
	ip route add default table 100 via $WAN_GATEWAY dev $WAN_INTERFACE
	ip rule add fwmark 1 table 100
	ip route flush cache

	# Default behavious : all traffic via VPN
	iptables -t mangle -A PREROUTING -j MARK --set-mark 0

	# SSH and Synology ports bypass VPN
	iptables -t mangle -A PREROUTING -p tcp -m multiport --dport "$RASPBERRY_PORTS,$SYNOLOGY_PORT" -j MARK --set-mark 1

	# Enable IP forwarding
	echo "1" > /proc/sys/net/ipv4/ip_forward

	# Redirect traffic from certains ports to Synology
	# http://www.debuntu.org/how-to-redirecting-network-traffic-to-a-new-ip-using-iptables/
	iptables -I FORWARD -p tcp -d "$SYNOLOGY_IP" --dport "$SYNOLOGY_PORT" -j ACCEPT
	iptables -I FORWARD -p tcp -s "$SYNOLOGY_IP" --sport "$SYNOLOGY_PORT" -j ACCEPT
	iptables -t nat -A PREROUTING -p tcp --dport "$SYNOLOGY_PORT" -j DNAT --to-destination "$SYNOLOGY_IP:$SYNOLOGY_PORT"
	iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

	# Open SSH & Synology ports on iptables
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

	daemonPid=$(cat /tmp/vpnfiles/vpndaemon.pid)
	# cf. http://www.linux-mag.com/id/5981
	if ps ax | grep -v grep | grep $daemonPid > /dev/null
    then
		echo "VPN daemon already running..."
	else
		(./tmp/vpnfiles/vpndaemon.sh &) &
		echo $! > /tmp/vpnfiles/vpndaemon.pid
	fi
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
		function getStatus {
			ifconfig | grep $1 && return 1
			return 0
		}

		while :
		do
			getStatus tun0
			if [[ $? == 0 ]]; then
				echo "OpenVPN not connected ! Reconnecting..."
				openvpn --daemon --config /tmp/vpnfiles/client.ovpn

				# Wait 1 minute before next check
				sleep 60
			else
				# Already connected, next check in 5 minutes
				sleep 300
			fi
		done
EOF

	chmod +x /tmp/vpnfiles/vpndaemon.sh

	# OpenVPN client config
	cat >> /tmp/vpnfiles/client.ovpn << EOF
		client
		dev tun
		proto udp
		remote 141.255.160.226 443
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
		connect-retry 10
		connect-retry-max infinite
		redirect-gateway def1
		user nobody
		group nobody
EOF

	# OpenVPN server certificate
	cat >> /tmp/vpnfiles/ca.crt << EOF
		-----BEGIN CERTIFICATE-----
		MIID5jCCA0+gAwIBAgIJAI5At1MshkY1MA0GCSqGSIb3DQEBBQUAMIGpMQswCQYD
		VQQGEwJVUzELMAkGA1UECBMCQ0ExFTATBgNVBAcTDFNhbkZyYW5jaXNjbzEVMBMG
		A1UEChMMRm9ydC1GdW5zdG9uMREwDwYDVQQLEwhjaGFuZ2VtZTEYMBYGA1UEAxMP
		MTQxLjI1NS4xNjAuMjI2MREwDwYDVQQpEwhjaGFuZ2VtZTEfMB0GCSqGSIb3DQEJ
		ARYQbWFpbEBob3N0LmRvbWFpbjAeFw0xMjExMjcwMzI0MjVaFw0yMjExMjUwMzI0
		MjVaMIGpMQswCQYDVQQGEwJVUzELMAkGA1UECBMCQ0ExFTATBgNVBAcTDFNhbkZy
		YW5jaXNjbzEVMBMGA1UEChMMRm9ydC1GdW5zdG9uMREwDwYDVQQLEwhjaGFuZ2Vt
		ZTEYMBYGA1UEAxMPMTQxLjI1NS4xNjAuMjI2MREwDwYDVQQpEwhjaGFuZ2VtZTEf
		MB0GCSqGSIb3DQEJARYQbWFpbEBob3N0LmRvbWFpbjCBnzANBgkqhkiG9w0BAQEF
		AAOBjQAwgYkCgYEA3kXxmykyskwKpbqsxAmBSeAXdgVsYPqpwxxmrHY0aLIziR/D
		y7vdsnWaiGUnoeH1+2vEiLBw/Yu/Mb2pT0+N+0/4IHe8vpS+X21eCpfZbrmzw2WO
		xeoL43IziYvuQkq9NyLp7+EF4uX3n5Z6iYL9WXIGDuibSzT1C0yiD852R00CAwEA
		AaOCARIwggEOMB0GA1UdDgQWBBSjVVGlxAHLsgIbZPNXr8kWyuI3djCB3gYDVR0j
		BIHWMIHTgBSjVVGlxAHLsgIbZPNXr8kWyuI3dqGBr6SBrDCBqTELMAkGA1UEBhMC
		VVMxCzAJBgNVBAgTAkNBMRUwEwYDVQQHEwxTYW5GcmFuY2lzY28xFTATBgNVBAoT
		DEZvcnQtRnVuc3RvbjERMA8GA1UECxMIY2hhbmdlbWUxGDAWBgNVBAMTDzE0MS4y
		NTUuMTYwLjIyNjERMA8GA1UEKRMIY2hhbmdlbWUxHzAdBgkqhkiG9w0BCQEWEG1h
		aWxAaG9zdC5kb21haW6CCQCOQLdTLIZGNTAMBgNVHRMEBTADAQH/MA0GCSqGSIb3
		DQEBBQUAA4GBAMqwhWOKEs+oB6OhyBcog7X6LszFVZNGRNRQVcmCvp2Ba6SXMpw3
		DtZ5L8SLV0eCulQ/WE3JmSyOu1j2mlbPS2258avko+qAFCF/aRZOQDYhN1zrcMOl
		JpLvMQZvNXybx8DeB7rIDQL4RfkDgxZSHy21x6Q5Qp26hFFoDvogqb0j
		-----END CERTIFICATE-----
EOF

}

# Call the main function
main "$1"