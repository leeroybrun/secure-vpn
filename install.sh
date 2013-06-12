#!/bin/bash

source ./config/config.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Login conf
echo "$VPN_USERNAME
$VPN_PASSWORD" > ./config/login.conf

cat >> /etc/network/if-up.d/secure-vpn << EOF
#!/bin/bash

$DIR/secure-vpn.sh start
EOF

chmod +x /etc/network/if-up.d/secure-vpn

exit 0