# Secure VPN scripts
Script used to etablish a secure VPN connection and block all traffic not going via the VPN.
You can define some ports to bypass the VPN.

You can also add multiple VPN servers, so when the script cannot connect to one server, it will try the next one.

The script allow you to speedtest all VPN servers listed in config to find the fastest one.

## Installation
Clone this repository where you want the script to live :

```bash
git clone git://github.com/leeroybrun/secure-vpn.git
```

Then customize the `config/config`, `config/servers.conf` and place your VPN servers certificates inside `config/certs/`.
If your server need custom OpenVPN settings, cou can edit the `config/client.ovpn` file.

When all settings are ready, call the install script :

```bash
sudo ./install.sh
```

This script will create some new config files and then install the script to call it when the network goes up.

## Usage

When the script is correctly installed, you can either call it directly, or reboot your computer to start it automatically.

If you call it automatically, here are the available commands :

- *./secure-vpn.sh start* : start the VPN and apply iptables rules
- *./secure-vpn.sh stop* : stop the VPN, but leave iptables rules in place
- *./secure-vpn.sh flush-iptables* : flush iptables rules
- *./secure-vpn.sh speedtest* : connect to each VPN servers defined in config & run a speedtest. It will then output the 10 best servers for Upload & Download.

## Todo :
- knock knock for ports opening
- auto detect local network
- store config in /etc/secure-vpn (create files with ./install.sh)