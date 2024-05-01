#!/bin/sh

echo "This script is VPN rotation plugin installation. Continue? (y/n)"
read answer
if [ "$answer"!= "y" ]; then
    echo "Installation cancelled."
    exit 1
fi

VPN_ROTATION_SCRIPT="/usr/bin/vpn_rotation.sh"
LUCI_MODULE_DIR="/usr/lib/lua/luci/controller/vpn_rotation"

if [ -f $VPN_ROTATION_SCRIPT ]; then
    cat << EOF > $VPN_ROTATION_SCRIPT
#!/bin/sh
WG_CONFIG_DIR="/etc/wireguard"
check_server_availability() {
    local config_file=$1
    wg show $config_file | grep -q "latest handshake: 1 minute, 59 seconds ago"
}
for config_file in $(ls $WG_CONFIG_DIR); do
    if check_server_availability $config_file; then
        echo "Switching to $config_file"
        wg-quick down wg0
        wg setconf wg0 $WG_CONFIG_DIR/$config_file
        wg-quick up wg0
        break
    else
        echo "$config_file is unavailable"
    fi
done
EOF
    chmod +x $VPN_ROTATION_SCRIPT
fi

if [ -d $LUCI_MODULE_DIR ]; then
    mkdir -p $LUCI_MODULE_DIR
fi

cat << EOF > $LUCI_MODULE_DIR/index.lua
module("luci.controller.vpn_rotation", package.seeall)
function index()
    entry({"admin", "services", "vpn_rotation"}, call("action_vpn_rotation"), _("VPN Rotation"), 60)
end
function action_vpn_rotation()
    local action = luci.http.formvalue("action")
    if action == "toggle" then
        local enabled = luci.sys.call("/usr/bin/vpn_rotation.sh toggle")
        luci.http.redirect(luci.dispatcher.build_url("admin", "services", "vpn_rotation"))
    end
end
EOF

echo "VPN rotation setup complete. The installation script has been removed."

rm $0
