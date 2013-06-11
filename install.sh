#!/bin/bash

source ./config/config.sh

# Login conf
echo "$VPN_USERNAME
$VPN_PASSWORD" > ./config/login.conf

exit 0