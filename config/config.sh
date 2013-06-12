#!/bin/bash

DIR_CONF="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $DIR_CONF/../../secure-vpn.conf

SRV_LINE_FORMAT="^[a-zA-Z0-9]+\ [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\ [0-9]+\ [a-z]{3}$"

#OPEN_PORTS="1234"

#SERVER_IP="xxx.xxx.xxx.xxx"

#LOCAL_NETWORK="192.168.1.0/24"
#WAN_INTERFACE="eth0"
#WAN_GATEWAY="192.168.1.1"

#VPN_USERNAME=""
#VPN_PASSWORD=""

#SPEEDTEST_CLI=""