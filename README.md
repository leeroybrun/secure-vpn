# Secure VPN scripts
Scripts used to etablish a secure VPN connection and block traffic not going via the VPN.

You can define some ports to bypass the VPN.

This script is used with a Raspberry Pi and a Synology, the two are connected to the VPN. Open ports on the Synology transit via the Raspberry because iproute2/kernel on the Synology isn't compiled with full functionnalities (no rules) and I wanted to leave it "standard" to not have surprises during updates :-).

## Todo :
    - knock knock for ports opening
    - automatically switch betweens servers if we cannot connect to one
    - auto detect local network