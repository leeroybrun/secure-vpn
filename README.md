# Secure VPN scripts
Script used to establish a secure VPN connection and block all traffic not going via the VPN.
You can define some ports to bypass the VPN.

You can also add multiple VPN servers, so when the script cannot connect to one server, it will try the next one.

The script allow you to speedtest all VPN servers listed in config to find the fastest one.

## Installation
Clone this repository where you want the script to live :

```shell
git clone git://github.com/leeroybrun/secure-vpn.git
```

Then you need to call the installer to copy all config files inside `/etc/secure-vpn/` :

```shell
sudo ./install config
```

You can now customize the config files inside `/etc/secure-vpn/`, specially `config`, `servers.conf` and place your VPN servers certificates inside `certs/`.
If your server need custom OpenVPN settings, you can edit the `client.ovpn` file.

When all settings are ready, you can make the script start every time your network goes up :

```shell
sudo ./install persist
```

## Usage

When the script is correctly installed, you can either call it directly, or reboot your computer to start it automatically.

If you call it manually, here are the available commands :

- `sudo ./secure-vpn.sh start` : start the VPN and apply iptables rules
- `sudo ./secure-vpn.sh stop` : stop the VPN, but leave iptables rules in place
- `sudo ./secure-vpn.sh flush-iptables` : flush iptables rules
- `sudo ./secure-vpn.sh speedtest` : connect to each VPN servers defined in config & run a speedtest. It will then output the 10 best servers and reorder your servers.conf file to put the bests on top.

## Todo :
- knock knock for ports opening
- auto detect local network