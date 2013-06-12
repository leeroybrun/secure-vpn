# Secure VPN scripts
Script used to etablish a secure VPN connection and block all traffic not going via the VPN.
You can define some ports to bypass the VPN.

You can also add multiple VPN servers, so when the script cannot connect to one server, it will try the next one.

## Todo :
- knock knock for ports opening
- Refactor code regarding multi server connection : automatically switch betweens servers if we cannot connect to one
  Use multiple remotes in client.ovpn : https://forums.openvpn.net/topic12684.html
  Define which protocol to use in config, then generate correct "remote" lines for client.ovpn with ./install.sh
  Keep ability to connect to one specific server (for speedtest)
- auto detect local network
- test speed of different servers