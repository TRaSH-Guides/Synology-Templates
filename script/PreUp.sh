wgserver=$(grep Endpoint "${CONFIG_DIR}/wireguard/wg0.conf" | awk '{print $3}')
gateway=$(ip -o -4 route show to default | awk '{print $3}')

ip -4 route add ${wgserver%:*} via ${gateway} dev eth0

# Download this file from the RAW link, not copy/paste it!
# place this file next to your wg0.conf
# add line "PreUp = bash /config/wireguard/PreUp.sh" to your wg0.conf at the [interfaces] section
