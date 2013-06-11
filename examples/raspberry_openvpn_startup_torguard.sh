#!/bin/bash
##########################################################################
#
#	TorGuard Raspbmc OpenVPN Startup Script
#
#	
#	Change this script and edit the line that says USERNAME so that 
#	it just contains your TorGuard username. In the same way, 
#	change the line that says PASSWORD so that it just contains 
#	your TorGuard password. 
#
##########################################################################
#
#	Please change the following two lines to use your TorGuard username and 
#	password. So for example, if your username was jacob and your password
#	was secret, the lines should read USER=Jason and PASS=mysecret
#
##########################################################################
#
USER=usernamehere
PASS=passwordhere
#
##########################################################################
#
#
##########################################################################
#
#
##########################################################################
#
#
##########################################################################
mkdir /tmp/torguard
cat > /tmp/torguard/user.txt << MARK1
$USER
$PASS
MARK1
chmod 0600 /tmp/torguard/user.txt
cat > /tmp/torguard/torguard.conf << MARK2
client
remote 184.75.220.26
dev tun
proto udp
port 443
resolv-retry infinite
nobind
route-delay 2
mute-replay-warnings
auth-user-pass user.txt
ca /tmp/torguard/ca.crt
keepalive 10 30
verb 3
mssfix 1450
MARK2
cat > /tmp/torguard/ca.crt << MARK3
-----BEGIN CERTIFICATE-----
MIID4DCCA0mgAwIBAgIJAN+rEp/JWhh5MA0GCSqGSIb3DQEBBQUAMIGnMQswCQYD
VQQGEwJVUzELMAkGA1UECBMCQ0ExFTATBgNVBAcTDFNhbkZyYW5jaXNjbzEVMBMG
A1UEChMMRm9ydC1GdW5zdG9uMREwDwYDVQQLEwhjaGFuZ2VtZTEWMBQGA1UEAxMN
MTg0Ljc1LjIyMC4yNjERMA8GA1UEKRMIY2hhbmdlbWUxHzAdBgkqhkiG9w0BCQEW
EG1haWxAaG9zdC5kb21haW4wHhcNMTMwMjI3MjMxNDE2WhcNMjMwMjI1MjMxNDE2
WjCBpzELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAkNBMRUwEwYDVQQHEwxTYW5GcmFu
Y2lzY28xFTATBgNVBAoTDEZvcnQtRnVuc3RvbjERMA8GA1UECxMIY2hhbmdlbWUx
FjAUBgNVBAMTDTE4NC43NS4yMjAuMjYxETAPBgNVBCkTCGNoYW5nZW1lMR8wHQYJ
KoZIhvcNAQkBFhBtYWlsQGhvc3QuZG9tYWluMIGfMA0GCSqGSIb3DQEBAQUAA4GN
ADCBiQKBgQDTl+hjSWkn6cEaeKTc/YqDVdSWka8CSYVM88N9SKegM8xsK0dfufUW
hgLxk5RSRFC9nJ6jr63MQe/AxxUndPgnIuMVdqQfa8ZukHk0oqifEM3pY8p7PKbd
kdE3IB3DSat3MEcwneEiRlFTJIQiYKPtoSFJsmNp+GKZX478x0uTxQIDAQABo4IB
EDCCAQwwHQYDVR0OBBYEFH1JVM5o4GA2chiYQGi6CSdpBeLfMIHcBgNVHSMEgdQw
gdGAFH1JVM5o4GA2chiYQGi6CSdpBeLfoYGtpIGqMIGnMQswCQYDVQQGEwJVUzEL
MAkGA1UECBMCQ0ExFTATBgNVBAcTDFNhbkZyYW5jaXNjbzEVMBMGA1UEChMMRm9y
dC1GdW5zdG9uMREwDwYDVQQLEwhjaGFuZ2VtZTEWMBQGA1UEAxMNMTg0Ljc1LjIy
MC4yNjERMA8GA1UEKRMIY2hhbmdlbWUxHzAdBgkqhkiG9w0BCQEWEG1haWxAaG9z
dC5kb21haW6CCQDfqxKfyVoYeTAMBgNVHRMEBTADAQH/MA0GCSqGSIb3DQEBBQUA
A4GBAGkXqdBKMzaEM+I69NkfhckhBnpZZTqAOvZGL2zvNGT1IKtVndK9lhz3opM/
hDX48VAXqyf5CVNP+66vyhn2/4iF5WEWs5rVVcxII2hWA0WKcF5lCXwMEXTo2H2d
mzJtZZY0/VaorbBXgRe1qXg+BQZP8ytCiUzbo2Fc0KdQ0zv+
-----END CERTIFICATE-----
MARK3
cat > /tmp/torguard/torguarddaemon << MARK4
#!/bin/sh
while :
do
date >> /tmp/torguard/torguard.log
sleep 60
NOPROCS=\`ps -ef | grep openvpn | grep -v grep | wc -l\`
if [ \$NOPROCS -eq 0 ]
then
echo "openvpn not running, starting again" >> /tmp/torguard/torguard.log
openvpn --config torguard.conf --daemon
else
echo "openvpn running, going back to sleep" >> /tmp/torguard/torguard.log
fi
done
MARK4
chmod a+x /tmp/torguard/torguarddaemon
cd /tmp/torguard
sleep 5
/tmp/torguard/torguarddaemon &
exit 0
##########################################################################
#	The End
##########################################################################
