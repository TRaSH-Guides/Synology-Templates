#!/bin/bash
set -euo pipefail

# Download this file from the RAW link, not copy/paste it!
# place this file next to your wg0.conf
# add line "PreUp = bash /config/wireguard/PreUp.sh" to your wg0.conf at the [interfaces] section
#
# CONFIG_DIR must point at the directory containing your wireguard/wg0.conf
# (e.g. /volume1/docker/wireguard-config), and must be set in the environment
# before this script runs.
: "${CONFIG_DIR:?CONFIG_DIR must be set to your wireguard config directory}"

wg_conf="${CONFIG_DIR}/wireguard/wg0.conf"
if [[ ! -f "${wg_conf}" ]]; then
    echo "PreUp.sh: ${wg_conf} not found, aborting (this exits non-zero, which wg-quick treats as fatal)" >&2
    exit 1
fi

wgserver=$(grep Endpoint "${wg_conf}" | awk '{print $3}')
gateway=$(ip -o -4 route show to default | awk '{print $3}')
default_iface=$(ip -o -4 route show to default | awk '{print $5}')

ip -4 route add "${wgserver%:*}" via "${gateway}" dev "${default_iface}"
