#!/bin/bash

DIR_CONF="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -f /etc/secure-vpn/config ]; then
	source /etc/secure-vpn/config
else
	$DIR_CONF/../install nonpersistent

SRV_LINE_FORMAT='^[a-zA-Z0-9]+\ [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\ [0-9]+\ [a-z]{3}$'