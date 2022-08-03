#!/usr/bin/env bash

# shellcheck disable=SC2034  # Unused variables left for readability

# MIT License

# Copyright (c) 2022 Bokkoman

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Author       - Ideas and original and code by @bokkoman.
# Contributors - Big thanks to @userdocs for helping with the script.
# Testers      - Thanks @Davo1624 for testing initial script. Xpenology for providing VM images.
# Credits      - https://trash-guides.info https://github.com/TRaSH-/Guides-Synology-Templates

## This script is created for Synology systems that support Docker. Tested on DSM v7.1

#################################################################################################################################################
# Color me up Scotty - define some color values to use as variables in the scripts - https://robotmoon.com/256-colors/
#################################################################################################################################################
cr="\e[31m" clr="\e[91m"       # [c]olor[r]ed     [c]olor[l]ight[r]ed
cg="\e[32m" clg="\e[92m"       # [c]olor[g]reen   [c]olor[l]ight[g]reen
cy="\e[33m" cly="\e[93m"       # [c]olor[y]ellow  [c]olor[l]ight[y]ellow
cb="\e[34m" clb="\e[94m"       # [c]olor[b]lue    [c]olor[l]ight[b]lue
cm="\e[35m" clm="\e[38;5;212m" # [c]olor[m]agenta [c]olor[l]ight[m]agenta
cc="\e[36m" clc="\e[38;5;81m"  # [c]olor[c]yan    [c]olor[l]ight[c]yan

tb="\e[1m" td="\e[2m" tu="\e[4m" tn="\n" tbk="\e[5m" # [t]ext[b]old [t]ext[d]im [t]ext[u]nderlined [t]ext[n]ewline [t]ext[b]lin[k]

utick="\e[32m\U2714\e[0m" uplus="\e[36m\U002b\e[0m" ucross="\e[31m\U00D7\e[0m" # [u]nicode][tick] [u]nicode][plus] [u]nicode][cross]

urc="\e[31m\U25cf\e[0m" ulrc="\e[38;5;9m\U25cf\e[0m"   # [u]nicode[r]ed[c]ircle     [u]nicode[l]ight[r]ed[c]ircle
ugc="\e[32m\U25cf\e[0m" ulgc="\e[92m\U25cf\e[0m"       # [u]nicode[g]reen[c]ircle   [u]nicode[l]ight[g]reen[c]ircle
uyc="\e[33m\U25cf\e[0m" ulyc="\e[93m\U25cf\e[0m"       # [u]nicode[y]ellow[c]ircle  [u]nicode[l]ight[y]ellow[c]ircle
ubc="\e[34m\U25cf\e[0m" ulbc="\e[94m\U25cf\e[0m"       # [u]nicode[b]lue[c]ircle    [u]nicode[l]ight[b]lue[c]ircle
umc="\e[35m\U25cf\e[0m" ulmc="\e[38;5;135m\U25cf\e[0m" # [u]nicode[m]agenta[c]ircle [u]nicode[l]ight[m]agenta[c]ircle
ucc="\e[36m\U25cf\e[0m" ulcc="\e[96m\U25cf\e[0m"       # [u]nicode[c]yan[c]ircle    [u]nicode[l]ight[c]yan[c]ircle
ugrc="\e[37m\U25cf\e[0m" ulgrcc="\e[97m\U25cf\e[0m"    # [u]nicode[gr]ey[c]ircle    [u]nicode[l]ight[gr]ey[c]ircle

cdef="\e[39m" # [c]olor[def]ault
bkend="\e[0m"
cend="\e[0m" # [c]olor[end]
#################################################################################################################################################
# check for root access and exit if the user does not have the required privileges.
#################################################################################################################################################
if [[ "$(id -un)" != 'root' ]]; then
    printf "\n%b\n" " ${ulrc} Please run this script with sudo to proceed"
    printf "\n%b\n\n" " ${utick} sudo ./$(basename -- "$0")"
    exit 1
fi
#################################################################################################################################################
# Hide thing or show them
#################################################################################################################################################
if [[ "${1}" == 'show' ]]; then
    hide_all='' hide_output='' hide_error=''
else
    hide_all='&> /dev/null' hide_output='1> /dev/null' hide_error='2> /dev/null'
fi
#################################################################################################################################################
# trap to catch errors
#################################################################################################################################################
err_report() {
    printf '\n%b\n\n' " ${ucross} Error on line $1 - script exited to allow for debugging"
    exit 1
}

trap 'err_report $LINENO' ERR
#################################################################################################################################################
# Multi select function
#################################################################################################################################################
function _multiselect {
    printf '\n'

    # Create an array of all container namees https://docs.docker.com/engine/reference/commandline/ps/#formatting
    mapfile -t installed_containers < <(docker ps --format "{{.Names}}")

    # Create our menu my_options associative array
    declare -A my_options
    eval "$(curl -sL "https://raw.githubusercontent.com/TRaSH-/Guides-Synology-Templates/main/templates/template-file-list.json" | jq -r '.templates | to_entries[]|@sh"my_options[\(.value)]=false"')"

    # Create some local arrays we need and make sure they're set to empty when the function is used/looped in the script
    local selected_values=()
    local selected_apps=()
    local lastrow
    local startrow
    # Create this global array we need fall through the function and make sure it is set to empty when the function is used/looped in the script
    selected_options=()

    # check the installed_containers array to see what is already installed, matched against our available_templates array so as not to add non template containers to the menu
    for index in "${installed_containers[@]}"; do
        if [[ "${!my_options[*]}" =~ ${index} ]]; then
            my_options["${index}"]="true"
        fi
    done

    # little helpers for terminal print control and key input
    # not really sure what this does or how it works.
    cursor_blink_on() { printf "\033[?25h"; }
    cursor_blink_off() { printf "\033[?25l"; }
    cursor_to() { printf '%b' "\033[${1};${2:-1}H"; }
    print_inactive() { printf '%b' "${2}   ${1} "; }
    print_active() { printf '%b' "${2}  \033[7m ${1} \033[27m"; }
    get_cursor_row() {
        IFS=';' read -rsdR -p $'\E[6n' ROW COL
        printf '%b' "${ROW#*[}"
    }

    # This will check the defaults of the my_options and set the menu option to true.
    # This eseentially switches back to an indexed array due to how the function toggle_option is working.
    for defaults in "${!my_options[@]}"; do
        if [[ "${my_options[$defaults]}" == 'true' ]]; then
            selected_values+=("true")
        else
            selected_values+=("false")
        fi
        printf "\n"
    done

    # determine current screen position for overwriting the my_options
    lastrow="$(get_cursor_row)"
    startrow="$((lastrow - ${#my_options[@]}))"

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    # not really sure what this does or how it works.
    key_input() {
        local key
        IFS= read -rsn1 key &> /dev/null
        case "${key}" in
            '')
                echo enter
                ;;
            $'\x20')
                echo space
                ;;
            'k')
                echo up
                ;;
            'j')
                echo down
                ;;
            $'\x1b')
                read -rsn2 key
                case "$key" in
                    '[A' | 'k')
                        echo up
                        ;;&
                    '[B' | 'j')
                        echo down
                        ;;&
                esac
                ;;
            *) ;;
        esac
    }

    # Passes the toggled options and a positional parameter number, 0 to 19 for example, and then sets the index matching that number to false or true. selected_values[2]=false, selected_values[16]=false
    toggle_option() {
        local option="${1}"
        if [[ "${selected_values[option]}" == 'true' ]]; then
            selected_values["$option"]=false
        else
            selected_values["$option"]=true
        fi
    }

    # not really sure what this does or how it works.
    print_options() {
        # print options by overwriting the last lines
        local idx=0
        for option in "${!my_options[@]}"; do
            local prefix=" [\e[38;5;9m×\e[0m]"
            if [[ ${selected_values[idx]} == true ]]; then
                prefix=" [\e[38;5;46m✔\e[0m]"
            fi

            cursor_to $((startrow + idx))
            if [[ "${idx}" -eq "${1}" ]]; then
                print_active "${option}" "${prefix}"
            else
                print_inactive "${option}" "${prefix}"
            fi
            ((idx++))
        done
    }

    local active=0
    while true; do
        print_options "${active}"
        # user key control
        case $(key_input) in
            space)
                toggle_option "${active}"
                ;;
            enter)
                print_options -1
                break
                ;;
            up)
                ((active--))
                if [[ "${active}" -lt 0 ]]; then active=$((${#my_options[@]} - 1)); fi
                ;;
            down)
                ((active++))
                if [[ "${active}" -ge "${#my_options[@]}" ]]; then active=0; fi
                ;;
        esac
    done

    # cursor position back to normal
    cursor_to "${lastrow}"
    printf "\n"
    cursor_blink_on

    if [[ ! "${selected_values[*]}" =~ 'true' ]]; then
        printf '%b\n' " ${ulrc} You must select at least one option to proceed. Try again"
        _multiselect
    else
        for values in "${!my_options[@]}"; do
            selected_apps+=("$values")
        done

        for count in "${!selected_apps[@]}"; do
            my_options[${selected_apps[$count]}]=${selected_values[$count]}
        done

        for final_selection in "${!my_options[@]}"; do
            if [[ "${my_options[$final_selection]}" == 'true' ]]; then
                selected_options+=("$final_selection")
            fi
        done

        # You can use thee "${selected_options[@]}" array to install apps as it is just the name of the app.
        printf '%b\n\n' " ${utick} You have selected:"
        printf " ${uyc} %s\n" "${selected_options[@]}"
        printf '\n'
    fi
}
#################################################################################################################################################
# Volumes, data and docker bootstrap
#################################################################################################################################################
# Create an array of all available volumes on this device
mapfile -t volume_list_array < <(mount -l | grep -E "/volume[0-9]{1,2}\s" | awk '{ print $3 }' | sort -V) # printf '%b\n' "${volume_list_array[@]}"
[[ "${#volume_list_array[@]}" -eq '1' ]] && docker_install_volume="${volume_list_array[0]}" docker_install_volume_id="${volume_list_array[0]#\/volume}"

# If docker is installed we will get the default path from docker and use that to set the variable - docker_install_volume - else set docker to be isntalled
if [[ "$(
    synopkg status Docker &> /dev/null
    printf '%b' "$?"
)" -le '1' ]]; then
    docker_install_volume="$(sed -rn 's|(.*)path=(/volume(.*))/docker|\2|p' /etc/samba/smb.share.conf)"
    install_docker="no"
else
    install_docker="yes"
fi

# if docker neeeds to be installed but there is more than one volume ask the user which volume they want to use for the installation and set this to the variable - docker_install_volume
if [[ "${install_docker}" == 'yes' && "${#volume_list_array[@]}" -gt '1' ]]; then
    PS3=$'\n \e[94m\U25cf\e[m '"Please select where to install docker from the list of volumes: "$'\n\n '
    printf "\n%b\n\n" " ${uyc} This is where docker will be installed and the conf dirs stored"
    select option in "${volume_list_array[@]}"; do # in "$@" is the default
        if [[ "$REPLY" -gt "${#volume_list_array[@]}" ]]; then
            printf '\n%b\n\n' " ${ucross}This is not a valid volume option, try again"
        else
            docker_install_volume="$(printf '%s' "${option}")"
            read -erp $'\n \e[32m\U2714\e[0m '"You selected "$'\e[96m'"${docker_install_volume}"$'\e[m'" is this correct "$'\e[32m'"[y]es"$'\e[m'" or "$'\e[31m'"[n]o"$'\e[m'" : " -i "y" confirm
            if [[ "${confirm}" =~ ^[yY](es)?$ ]]; then
                docker_install_volume_id="${docker_install_volume#\/volume}"
                break
            fi
        fi
    done
fi

if [[ "${#volume_list_array[@]}" -gt '1' ]]; then
    existing_data_share=$(synoshare --get data | sed -rn 's#^(.*)Path(.*)\[(.*)/data\]$#\3#p')
    if [[ -z "${existing_data_share}" ]]; then
        # If there is more than one volume ask the user which volume they want to use for the data directories and set this to the variable - docker_data_volume
        PS3=$'\n \e[94m\U25cf\e[m '"Please select a data volume from the list of volumes: "$'\n\n '
        printf "\n%b\n\n" " ${uyc} This volume is where the data files will be stored (movies, shows, etc)"
        select option in "${volume_list_array[@]}"; do # in "$@" is the default
            if [[ "$REPLY" -gt "${#volume_list_array[@]}" ]]; then
                printf '\n%b\n\n' " ${ucross}This is not a valid volume option, try again"
            else
                docker_data_volume="$(printf '%s' "${option}")"
                read -erp $'\n \e[32m\U2714\e[0m '"You selected "$'\e[96m'"${docker_data_volume}"$'\e[m'" is this correct "$'\e[32m'"[y]es"$'\e[m'" or "$'\e[31m'"[n]o"$'\e[m'" : " -i "y" confirm
                if [[ "${confirm}" =~ ^[yY](es)?$ ]]; then
                    docker_data_dir_id=${docker_data_volume#\/volume}
                    break
                fi
            fi
        done
    else
        printf "\n%b\n" " ${uyc} Using existing data share found at ${clc}${existing_data_share}/data${cend}"
        docker_data_volume="${existing_data_share}"
        docker_data_dir_id="${existing_data_share#\/volume}"
    fi
fi
#################################################################################################################################################
# Default values
#################################################################################################################################################
user="docker"                                                                                  # {Update me if needed} User App will run as and the owner of it's binaries
group="users"                                                                                  # {Update me if needed} Group App will run as.
password=$(openssl rand -base64 14)                                                            # generate a password
docker_conf_dir="${docker_install_volume}/docker"                                              # docker directory
docker_data_dir="${docker_data_volume:-${docker_install_volume}}/data"                         # /data share
docker_data_dir_id="${docker_data_dir_id:-${docker_install_volume_id}}"                        # /volume{id} - just the number
ip="$(ip route get 1 | awk '{print $NF;exit}')"                                                # get local ip
gateway="$(ip route | grep "$(ip route get 1 | awk '{print $7}')" | awk 'FNR==2{print $1}')"   # get gateway ip
TZ="$(realpath --relative-to /usr/share/zoneinfo /etc/localtime)"                              # get timezone
synoinfo_default_path="$(sed -rn 's|(.*)(pkg_def_intall_vol="(.*)")|\2|p' /etc/synoinfo.conf)" # set the default path for app installations.
qsv="/dev/dri/"
# get the lastest docker version by scraping the archive.synology.com page for the package.
docker_version=$(curl -sL "https://archive.synology.com/download/Package/Docker" | sed -rn 's|(.*)href="/download/Package/Docker/(.*)" (.*)|\2|p' | head -n 1) # get the lastest docker version
#################################################################################################################################################
# Install Docker
#################################################################################################################################################
# Install docker if install_docker=yes or skip
if [[ "${install_docker}" == 'yes' ]]; then
    printf "\n%b\n\n" " ${uplus} Installing Docker package"
    # We need to change this to the selected path to make it install where the user chose for it to go. Then reveert it back to default after.
    if [[ "${#volume_list_array[@]}" -gt '1' ]]; then
        if grep -Eq '^pkg_def_intall_vol="(.*)"$' /etc/synoinfo.conf; then
            printf '%b\n\n' " ${ulmc} Modifying ${clc}pkg_def_intall_vol${cend} to ${clc}${docker_install_volume}${cend}"
            sed -r 's|pkg_def_intall_vol="(.*)"|pkg_def_intall_vol="'"${docker_install_volume}"'"|g' -i.synoinfo.conf.bak-"$(date +%H-%M-%b)" /etc/synoinfo.conf
        else
            printf '%b\n\n' " ${ulmc} Setting ${clc}pkg_def_intall_vol${cend} to ${clc}${docker_install_volume}${cend}"
            printf '%s\n' "pkg_def_intall_vol=\"${docker_install_volume}\"" >> /etc/synoinfo.conf
        fi
        synoinfo_modified="true"
    fi

    wget -qO "${docker_install_volume}/docker.spk" "https://global.download.synology.com/download/Package/spk/Docker/${docker_version}/Docker-x64-${docker_version}.spk"
    eval synopkg install "${docker_install_volume}/docker.spk" "${hide_all}"

    # We need to change this to back to the default after the docker application is installed
    if [[ "${synoinfo_modified}" == 'true' && -n "${synoinfo_default_path}" ]]; then
        printf '%b\n' " ${uyc} ${clc}synoinfo_default_path${cend} was reverted to: ${clc}${synoinfo_default_path}${cend}"
        sed -r 's|pkg_def_intall_vol="(.*)"|pkg_def_intall_vol="'"$synoinfo_default_path"'"|g' -i /etc/synoinfo.conf
    else
        printf '%b\n' " ${uyc} ${clc}synoinfo_default_path${cend} was not set and reverted to empty"
        sed -r 's|pkg_def_intall_vol="(.*)"|pkg_def_intall_vol=""|g' -i /etc/synoinfo.conf
    fi
else
    printf "\n ${utick} %b\n" "Docker package is already installed"
fi

synopkg start Docker &> /dev/null
#################################################################################################################################################
# Test Docker
#################################################################################################################################################
if [[ "$(
    synopkg status Docker &> /dev/null
    printf '%s' "$?"
)" -le '0' ]]; then
    [[ -f "${docker_install_volume}/docker.spk" ]] && rm -f "${docker_install_volume}/docker.spk"
    printf '\n%b\n' " ${utick} Docker is running!"
else
    printf '\n%b\n\n' " ${ucross} Docker installation has not worked, please try again"
    exit 1
fi
#################################################################################################################################################
# Check for user
#################################################################################################################################################
printf '\n%b\n' " ${ulbc} Checking if user ${clm}docker${cend} exists"
if ! synouser --get "${user}" &> /dev/null; then
    printf '\n%b\n' " ${ucross} The user ${clm}docker${cend} doesn't exist, creating."
    synouser --add "${user}" "${password}" "Docker User" 0 "" 0
    printf '\n%b\n' " ${utick} User ${clm}docker${cend} created!"
else
    printf '\n%b\n' " ${utick} User ${clm}docker${cend} exists!"
fi
#################################################################################################################################################
# check for /data share
#################################################################################################################################################
printf '\n%b\n' " ${ulbc} Checking if ${clc}/data${cend} shares exist"
if [[ -d "${docker_data_dir}" ]]; then
    ### Take action if ${docker_data_dir} exists ###
    printf '\n%b\n' " ${utick} ${clc}${docker_data_dir}${cend} share exists!"
else
    ###  Control will jump here if ${docker_data_dir} does NOT exists ###
    printf '\n%b\n' " ${ucross} ${clc}${docker_data_dir}${cend} doesn't exist, creating."
    if synoshare --get data &> /dev/null; then
        synoshare --setvol data "${docker_data_dir_id}"
    else
        synoshare --add data "Data Directory" "${docker_data_dir}" "" "${user}" "" 1 0
    fi
    printf '\n%b\n' " ${utick} Created ${clc}${docker_data_dir}${cend}"
fi

printf '\n%b\n' " ${ulmc} Setting user rights to shares"

[[ -z "${hide_all}" ]] && printf '\n'
eval synoshare --setuser data RW + ${user},@${group} "${hide_all}"
eval synoshare --setuser docker RW + ${user},@${group} "${hide_all}"

printf '\n%b\n' " ${utick} User has rights to share."
#################################################################################################################################################
# VPN stuff
#################################################################################################################################################
# Create the necessary file structure for vpn tunnel device
# Thanks @Gabe
if ! lsmod | grep -q "^tun\s"; then
    insmod /lib/modules/tun.ko
    cat > "/usr/local/etc/rc.d/tun.sh" << EOF
    #!/bin/sh -e

    insmod /lib/modules/tun.ko
EOF
    chmod a+x /usr/local/etc/rc.d/tun.sh
fi
#################################################################################################################################################
# Create docker-compose.yml and download .env
#################################################################################################################################################
printf '\n%b\n' " ${ulmc} bootstrapping docker-compose.yml"
mkdir -p "${docker_conf_dir}/appdata"
cat > "${docker_conf_dir}/appdata/docker-compose.yml" << EOF
version: "3.2"
services:
EOF
printf '\n%b\n' " ${utick} docker-compose.yml bootstrapped"

printf '\n%b\n' " ${ulmc} Downloading docker .env"
if wget -qO "${docker_conf_dir}/appdata/.env" https://raw.githubusercontent.com/TRaSH-/Guides-Synology-Templates/main/docker-compose/.env; then
    printf '\n%b\n' " ${utick} Docker .env downloaded."
else
    printf '\n%b\n' " ${ucross} There was a problem downloading then .env, try again"
    exit 1
fi

printf '\n%b\n' " ${ulmc} Setting correct User ID in .env"
sed -i "s|PUID=1035|PUID=$(id "${user}" -u)|g" "${docker_conf_dir}/appdata/.env"
printf '\n%b\n' " ${utick} User ID set.."

printf '\n%b\n' " ${ulmc} Setting local IP in .env"
sed -i "s|192.168.x.x:32400|${ip}:32400|g" "${docker_conf_dir}/appdata/.env"
printf '\n%b\n' " ${utick} Local IP set."

printf '\n%b\n' " ${ulmc} Setting local Gateway in .env"
sed -i "s|LAN_NETWORK=192.168.x.x/24|LAN_NETWORK=$gateway|g" "${docker_conf_dir}/appdata/.env"
printf '\n%b\n' " ${utick} local Gateway set."

printf '\n%b\n' " ${ulmc} Setting timezone in .env"
sed -i "s|Europe/Amsterdam|${TZ}|g" "${docker_conf_dir}/appdata/.env"
printf '\n%b\n' " ${utick} Timezone set."

printf '\n%b\n' " ${ulmc} Setting correct docker config dir in then .env"
sed -i "s|DOCKERCONFDIR=/volume1/docker|DOCKERCONFDIR=${docker_conf_dir}|g" "${docker_conf_dir}/appdata/.env"
printf '\n%b\n' " ${utick} ${clc}${docker_conf_dir}${cend} set."

printf '\n%b\n' " ${ulmc} Setting correct docker storage dir in the .env"
sed -i "s|DOCKERSTORAGEDIR=/volume1/data|DOCKERSTORAGEDIR=${docker_data_dir}|g" "${docker_conf_dir}/appdata/.env"
printf '\n%b\n' " ${utick} ${clc}${docker_data_dir}${cend} set."
#################################################################################################################################################
# compose template downloader
#################################################################################################################################################
get_app_compose() {
    if wget -qO "${docker_conf_dir}/appdata/${1}.yml" "https://raw.githubusercontent.com/TRaSH-/Guides-Synology-Templates/main/templates/${1,,}.yml"; then
        printf '\n' >> "${docker_conf_dir}/appdata/docker-compose.yml"

        [[ "${options}" = 'sabnzbd' ]] && sed -r 's|- 8080:8080$|- 7080:8080|g' -i "${docker_conf_dir}/appdata/${1}.yml"
        [[ "${options}" == 'dozzle' ]] && sed -r 's|- 8080:8080$|- 7081:8080|g' -i "${docker_conf_dir}/appdata/${1}.yml"
        [[ "${options}" == 'qbittorrent' ]] && sed -r -e 's|devices:|devices: #qbit|g' -i "${docker_conf_dir}/appdata/${1}.yml" && sed -r 's|- /dev/net/tun:/dev/net/tun|- /dev/net/tun:/dev/net/tun #qbit|g' -i "${docker_conf_dir}/appdata/${1}.yml"

        sed -n 'p' "${docker_conf_dir}/appdata/${1}.yml" >> "${docker_conf_dir}/appdata/docker-compose.yml"
        rm -f "${docker_conf_dir}/appdata/${1}.yml"
        printf '\n%b\n' " ${utick} ${1,,} template added to compose."
    else
        printf '\n%b\n' " ${ucross} There was a problem downloading the template for ${1,,}, try again"
        exit 1
    fi
}
#################################################################################################################################################
# Run _multiselect function
#################################################################################################################################################
printf '\n%b' " arrow down => down"
printf '\n%b' " arrow up   => up"
printf '\n%b' " Space bar  => toggle selection"
printf '\n%b\n' " Enter key  => confirm selection"
_multiselect
#################################################################################################################################################
# Process selections
#################################################################################################################################################
while true; do
    read -erp $' \e[32m\U2714\e[0m '"Is this correct selection? "$'\e[38;5;10m'"[y]es"$'\e[m'" or "$'\e[38;5;9m'"[n]o"$'\e[m'" : " -i "y" yesno
    case "${yesno}" in
        [Yy]*)
            printf '\n%b\n' " ${ulmc} Creating docker-compose"
            for options in "${selected_options[@]}"; do
                mkdir -p "${docker_conf_dir}/appdata/${options}"
                get_app_compose "${options}"
                [[ "${options}" == 'plex' ]] && plex_installed="yes"
                [[ "${options}" == 'qbittorrent' ]] && qbit_installed="yes"
                [[ "${options}" == 'radarr' ]] && mkdir -p "${docker_data_dir}/media/movies"
                [[ "${options}" == 'sonarr' ]] && mkdir -p "${docker_data_dir}/media/tv"
                [[ "${options}" =~ ^(sabnzbd|nzbget)$ ]] && mkdir -p "${docker_data_dir}"/usenet/{tv,movies}
                [[ "${options}" == 'qbittorrent' ]] && mkdir -p "${docker_data_dir}"/torrents/{tv,movies}
            done

            if [[ "${plex_installed}" == "yes" ]]; then
                #check for quick sync
                if [[ -d "$qsv" ]]; then
                    ### Do nothing if $qsv exists.
                    printf '\n%b\n' " ${utick} Intel Quick Sync found for Plex Hardware Transcoding."
                else
                    ### Take action if $qsv does not exist.
                    sed -r "s|^(.*)devices:(.*)# optional: if you have a Syno with an Intel CPU(.*)|#\1devices:\2# optional: if you have a Syno with an Intel CPU\3|g" -i "${docker_conf_dir}/appdata/docker-compose.yml"
                    sed -r "s|^(.*)- /dev/dri:/dev/dri(.*)# optional: if you have a Syno with an Intel CPU(.*)|#\1- /dev/dri:/dev/dri(.*)\2# optional: if you have a Syno with an Intel CPU\3|g" -i "${docker_conf_dir}/appdata/docker-compose.yml"
                    printf '\n%b\n' " ${ucross} No Intel Quick Sync found for Plex Hardware Transcoding."
                fi
            fi

            if [[ "${qbit_installed}" == "yes" ]]; then
                while true; do
                    read -erp $'\n \e[32m\U2714\e[0m '"Do you want Qbittorrent installed with VPN? "$'\e[38;5;10m'"[y]es"$'\e[m'" or "$'\e[38;5;9m'"[n]o"$'\e[m'" : " -i "" yesno
                    case "${yesno}" in
                        [Yy]*)
                            printf '\n%b\n\n' " ${utick} With VPN"
                            mkdir -p "${docker_conf_dir}/appdata/qbittorrent/wireguard"
                            read -erp $' \e[93m\U25cf\e[0m '"Place your "$'\e[38;5;81m'"wg0.conf"$'\e[m'" in:"$'\n\n \e[38;5;81m'"${docker_conf_dir}/appdata/qbittorrent/wireguard"$'\e[m\n\n \e[93m\U25cf\e[0m '"When that is done please confirm "$'\e[38;5;10m'"[y]es"$'\e[m'" : " -i "" yes
                            case "${yes}" in
                                [Yy]*)
                                    if sed -r 's|AllowedIPs = (.*)|AllowedIPs = 0.0.0.0/1,128.0.0.0/1|g' -i "${docker_conf_dir}/appdata/qbittorrent/wireguard/wg0.conf" 2> /dev/null; then
                                        printf '\n%b\n' " ${utick} wg0.conf found and fixed."
                                    else
                                        printf '\n%b\n\n ' " ${ucross} wg0.conf not found. Place file with filename ${clc}wg0.conf${cend} and restart script."
                                        exit 1
                                    fi
                                    break
                                    ;;
                            esac
                            ;;
                        [Nn]*)
                            printf '\n%b\n' " ${ucross} Without VPN."
                            sed -r 's|VPN_ENABLED=true|VPN_ENABLED=false|g' -i "${docker_conf_dir}/appdata/.env"
                            sed -r 's|devices: #qbit|#devices: #qbit|g' -i "${docker_conf_dir}/appdata/docker-compose.yml"
                            sed -r 's|- /dev/net/tun:/dev/net/tun #qbit|#- /dev/net/tun:/dev/net/tun #qbit|g' -i "${docker_conf_dir}/appdata/docker-compose.yml"
                            break
                            ;;
                    esac
                done
            fi
            printf '\n%b\n' " ${ulmc} Doing final permissions stuff"
            chown -R "${user}":"${group}" "${docker_data_dir}" "${docker_conf_dir}"
            chmod -R a=,a+rX,u+w,g+w "${docker_data_dir}" "${docker_conf_dir}"
            printf '\n%b\n' " ${utick} Permissions set."

            printf '\n%b\n' " ${uplus} Installing Pullio for auto updates"
            if wget -qO /usr/local/bin/pullio "https://raw.githubusercontent.com/hotio/pullio/master/pullio.sh"; then
                chmod +x /usr/local/bin/pullio
                printf '\n%b\n' " ${utick} Pullio installed"
            else
                printf '\n%b\n' " ${ucross} There was a problem downloading then /usr/local/bin/pullio, try again"
                exit 1
            fi

            printf '\n%b\n' " ${ulmc} Creating task for auto updates"
            if grep -q '/usr/local/bin/pullio' /etc/crontab; then
                sed -e '/\/usr\/local\/bin\/pullio/d' -e '/^$/d' -i.bak-"$(date +%H-%M-%b)" /etc/crontab
            else
                cp -f /etc/crontab /etc/crontab.bak-"$(date +%H-%M-%b)"
            fi

            printf '%b\n' '0    3    *    *    7    root    /usr/local/bin/pullio &>> '"${docker_conf_dir}"'/appdata/pullio/pullio.log' >> /etc/crontab
            sed 's/    /\t/g' -i /etc/crontab
            systemctl -q restart crond
            systemctl -q restart synoscheduler
            printf '\n%b\n' " ${utick} Task Created"

            printf '\n%b\n\n' " ${uplus} Installing the selected containers"
            cd "${docker_conf_dir}/appdata/" || return
            docker-compose up -d --remove-orphans
            printf '\n%b\n\n' " ${utick} All set, everything should be running. If you have errors, follow the complete guide. And join our discord server."
            break
            ;;
        [Nn]*)
            _multiselect
            ;;
        *) printf '\n%b\n\n' " ${ulrc} Please answer ${clg}[y]es${cend} or ${clr}[n]o${cend}" ;;
    esac
done

exit
