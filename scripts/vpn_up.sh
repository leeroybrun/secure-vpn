#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $DIR/../config/config.sh

# Delete table 100 and flush all existing rules
ip route flush table 100
ip route flush cache

# https://forum.linode.com/viewtopic.php?p=50114&sid=b440414422596bb7dbc96cf7c9ee511f#p50114
# Allow packets to go back to eth0 interface, as all ports are blocked, only the allowed ones will be routed
ip rule add from 91.121.166.103 table 100
#ip route add table 100 to 91.121.166.0/24 dev eth0
ip route add table 100 default via 91.121.166.254