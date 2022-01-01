#!/usr/bin/env bash

# MIT License

# Copyright (c) 2021 Bokkoman

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
# Testers      - Thanks @Davo1624 for testing.
# Supporters   - @thezak48 for not getting upset we spammed the #general channel
# Credits      - https://trash-guides.info https://github.com/TRaSH-/Guides-Synology-Templates

## This script is created for Synology systems that support Docker. Tested on DSM v7.

# check for root access and exit if the user does not have the required privilages.
if [[ "$(id -un)" != 'root' ]]; then
    printf '\n%s\n' "Please run this script with sudo to proceed"
    printf '\n%s\n\n' "sudo ./$(basename -- "$0")"
    exit 1
fi

# Some colour output for printf - start color with ${col_red} end it with ${col_end}: printf '\n%b\n' "${col_red}This will be red text${col_end} this will be normal text"
col_red="\e[1;31m"
col_green="\e[1;32m"
col_yellow="\e[1;33m"
# col_blue="\e[1;34m"
# col_magenta="\e[1;35m"
# col_cyan="\e[1;36m"
col_end="\e[0m"

# Create an array of all available volumes on this device
mapfile -t volume_list_array < <(mount -l | grep -E "/volume[0-9]{1,2}\s" | awk '{ print $3 }' | sort -V) # printf '%s\n' "${volume_list_array[@]}"

# if there is only one volume default to that else ask the user where they want to install stuff
if [[ "${#volume_list_array[@]}" -eq '1' ]]; then
    docker_install_volume="${volume_list_array[0]}"
else
    if [[ "$(# if docker is already installed, active or stopped, get the default share path and use that automatically, skipping the docker prompts.
        synopkg status Docker &> /dev/null
        printf '%s' "$?"
    )" -le '1' ]]; then
        # if docker is installed but there is more than one volume get the default path and set to the variable - docker_install_volume
        docker_install_volume="$(sed -rn 's|(.*)path=(/volume(.*))/docker|\2|p' /etc/samba/smb.share.conf)"
        install_docker="no"
    elif [[ "$(# if docker is not installed actiave the docker prompts
        synopkg status Docker &> /dev/null
        printf '%s' "$?"
    )" -gt '1' ]]; then
        # if docker is not installed but there is more than one volume ask the user which volume they want to use for the installation and set this to the variable - docker_install_volume
        PS3=$'\n'"Please select where to install docker from the list of volumes: "
        printf "\n%b\n\n" "${col_green}This is where docker will be installed and the conf dirs stored${col_end}"
        select option in "${volume_list_array[@]}"; do # in "$@" is the default
            if [[ "$REPLY" -gt "${#volume_list_array[@]}" ]]; then
                printf '\n%b\n' "${col_red}This is not a valid volume option, try again.${col_end}"
            else
                docker_install_volume="$(printf '%s' "${option}")"
                printf '%b\n' "${col_yellow}"
                read -erp "You selected ${docker_install_volume} is this correct: " -i "yes" confirm
                printf '%b' "${col_end}"
                [[ "${confirm}" =~ ^[yY](es)?$ ]] && break
            fi
        done
        install_docker="yes"
    fi

    # If there is more than one volume ask the user which volume they want to use for the data directories and set this to the variable - docker_data_volume
    PS3=$'\n'"Please select a data volume from the list of volumes: "
    printf "\n%b\n\n" "${col_green}This volume is where the data files will be stored (movies, shows, etc)${col_end}"
    select option in "${volume_list_array[@]}"; do # in "$@" is the default
        if [[ "$REPLY" -gt "${#volume_list_array[@]}" ]]; then
            printf '\n%b\n' "${col_red}This is not a valid volume option, try again.${col_end}"
        else
            docker_data_volume="$(printf '%s' "${option}")"
            printf '%b\n' "${col_yellow}"
            read -erp "You selected $docker_data_volume is this correct: " -i "yes" confirm
            printf '%b' "${col_end}"
            [[ "${confirm}" =~ ^[yY](es)?$ ]] && break
        fi
    done
fi

user="docker"                                                                                  # {Update me if needed} User App will run as and the owner of it's binaries
group="users"                                                                                  # {Update me if needed} Group App will run as.
password=$(openssl rand -base64 14)                                                            # generate a password
docker_conf_dir="${docker_install_volume}/docker"                                              # docker directory
docker_data_dir="${docker_data_volume:-${docker_install_volume}}/data"                         # /data share
ip="$(ip route get 1 | awk '{print $NF;exit}')"                                                # get local ip
gateway="$(ip route | grep "$(ip route get 1 | awk '{print $7}')" | awk 'FNR==2{print $1}')"   # get gateway ip
TZ="$(realpath --relative-to /usr/share/zoneinfo /etc/localtime)"                              # get timezone
synoinfo_default_path="$(sed -rn 's|(.*)(pkg_def_intall_vol="(.*)")|\2|p' /etc/synoinfo.conf)" # set the default path for app installations.
qsv="/dev/dri/"

# get the lastest docker version by scraping the archive.synology.com page for the package.
docker_version=$(curl -sL "https://archive.synology.com/download/Package/Docker" | sed -rn 's|(.*)href="/download/Package/Docker/(.*)" (.*)|\2|p' | head -n 1) # get the lastest docker version

# Set the brace expanded filepaths into arrays so that we can create them easily with mkdir and a quoted expansion
mapfile -t mkdir_appdata < <(printf '%s\n' "$docker_conf_dir"/appdata/{radarr,sonarr,bazarr,plex,pullio}) # mkdir -p "${mkdir_appdata[@]}"
mapfile -t mkdir_media < <(printf '%s\n' "$docker_data_dir"/media/{tv,movies,music})                      # mkdir -p "${mkdir_media[@]}"
mapfile -t mkdir_usenet < <(printf '%s\n' "$docker_data_dir"/usenet/{tv,movies,music})                    # mkdir -p "${mkdir_usenet[@]}"
mapfile -t mkdir_torrents < <(printf '%s\n' "$docker_data_dir"/torrents/{tv,movies,music})                # mkdir -p "${mkdir_torrents[@]}"

# Install docker if install_docker=yes or skip
if [[ "${install_docker}" == 'yes' ]]; then
    printf '\n%s\n\n' "Installing Docker package..."

    if [[ "${#volume_list_array[@]}" -gt '1' ]]; then
        sed -r 's|pkg_def_intall_vol="(.*)"|pkg_def_intall_vol="'"$docker_install_volume"'"|g' -i.synoinfo.conf.bak-"$(date +%H-%M-%S)" /etc/synoinfo.conf
        synoinfo_modified="true"
    fi

    wget -qO "$docker_install_volume/docker.spk" "https://global.download.synology.com/download/Package/spk/Docker/$docker_version/Docker-x64-$docker_version.spk"
    synopkg install "$docker_install_volume/docker.spk"

    if [[ "${synoinfo_modified}" == 'true' ]]; then
        sed -r 's|pkg_def_intall_vol="(.*)"|pkg_def_intall_vol="'"$synoinfo_default_path"'"|g' -i /etc/synoinfo.conf
    fi
else
    printf '\n%s\n\n' "Docker package is already installed ..."
fi

synopkg start Docker &> /dev/null

if [[ "$(
    synopkg status Docker &> /dev/null
    printf '%s' "$?"
)" -le '0' ]]; then
    [[ -f "$docker_install_volume/docker.spk" ]] && rm -f "$docker_install_volume/docker.spk"
    printf '\n%b\n\n' "${col_red}Docker has been started and is running${col_end}"
else
    printf '\n%b\n\n' "${col_red}Docker installation has not worked, please try again${col_end}"
    exit 1
fi

#check for $user
printf '\n%s\n\n' "Checking if user 'docker' exists..."
if ! synouser --get "$user" &> /dev/null; then
    printf '\n%s\n' "The user 'docker' doesn't exist, creating."
    synouser --add "$user" "$password" "Docker User" 0 "" 0
else
    printf '\n%s\n' "User 'docker' exists. Carry on."
fi

#check for /data share
printf '\n%s\n\n' "Checking if /data share excists..."
if [[ -d "$docker_data_dir" ]]; then
    ### Take action if $docker_data_dir exists ###
    printf '\n%s\n' "$docker_data_dir share exist, continuing..."
else
    ###  Control will jump here if $docker_data_dir does NOT exists ###
    printf '\n%s\n' "$docker_data_dir share does not exist, creating"
    synoshare --add data "Data Directory" "${docker_data_dir}" "" "$user" "" 1 0
fi

printf '\n%s\n\n' "Setting user rights to shares..."
synoshare --setuser data RW + $user,@$group
synoshare --setuser docker RW + $user,@$group
printf '\n%s\n\n' "User has rights to share."

printf '\n%s\n\n' "Creating appdata directories..."
mkdir -p "${mkdir_appdata[@]}"
printf '\n%s\n\n' "Appdata directories created."

printf '\n%s\n\n' "Creating media directories..."
mkdir -p "${mkdir_media[@]}"
printf '\n%s\n\n' "Media directories created."

printf '\n%s\n' "Downloading docker compose..."
if wget -qO "$docker_conf_dir/appdata/docker-compose.yml" https://raw.githubusercontent.com/TRaSH-/Guides-Synology-Templates/main/docker-compose/docker-compose.yml; then
    printf '\n%s\n' "Docker compose downloaded."
else
    printf '\n%s\n' "There was a problem downloading then docker-compose.yml, try again"
    exit 1
fi

printf '\n%s\n' "Downloading docker env..."
if wget -qO "$docker_conf_dir/appdata/.env" https://raw.githubusercontent.com/TRaSH-/Guides-Synology-Templates/main/docker-compose/.env; then
    printf '\n%s\n' "Docker .env downloaded."
else
    printf '\n%s\n' "There was a problem downloading then .env, try again"
    exit 1
fi

#check for quick sync
if [[ -d "$qsv" ]]; then
    ### Do nothing if $qsv exists.
    printf '\n%s\n' "Intel Quick Sync found for Plex Hardware Transcoding."
else
    ### Take action if $qsv does not exist.
    sed -i "s|    devices:|#    devices:|g" "$docker_conf_dir/appdata/docker-compose.yml"
    sed -i "s|      - /dev/dri:/dev/dri|#      - /dev/dri:/dev/dri|g" "$docker_conf_dir/appdata/docker-compose.yml"
    printf '\n%s\n' "No Intel Quick Sync found for Plex Hardware Transcoding."
fi

printf '\n%s\n\n' "Setting correct User ID in .env ..."
sed -i "s|PUID=1035|PUID=$(id "$user" -u)|g" "$docker_conf_dir/appdata/.env"
printf '\n%s\n\n' "User ID set.."

printf '\n%s\n\n' "Setting local IP in .env ..."
sed -i "s|192.168.x.x:32400|$ip:32400|g" "$docker_conf_dir/appdata/.env"
printf '\n%s\n\n' "Local IP set."

printf '\n%s\n\n' "Setting local Gateway in .env ..."
sed -i "s|LAN_NETWORK=192.168.x.x/24|LAN_NETWORK=$gateway|g" "$docker_conf_dir/appdata/.env"
printf '\n%s\n\n' "local Gateway set."

printf '\n%s\n\n' "Setting timezone in .env ..."
sed -i "s|Europe/Amsterdam|$TZ|g" "$docker_conf_dir/appdata/.env"
printf '\n%s\n\n' "Timezone set."

printf '\n%s\n\n' "Setting correct docker config dir in then .env ..."
sed -i "s|DOCKERCONFDIR=/volume1/docker|DOCKERCONFDIR=$docker_conf_dir|g" "$docker_conf_dir/appdata/.env"
printf '\n%s\n\n' "/volume set."

printf '\n%s\n\n' "Setting correct docker storage dir in the .env ..."
sed -i "s|DOCKERSTORAGEDIR=/volume1/data|DOCKERSTORAGEDIR=$docker_data_dir|g" "$docker_conf_dir/appdata/.env"
printf '\n%s\n\n' "/volume set."

get_app_compose() {
    if wget -qO "$docker_conf_dir/appdata/$1.yml" "https://raw.githubusercontent.com/TRaSH-/Guides-Synology-Templates/main/templates/$1.yml"; then
        printf '\n' >> "$docker_conf_dir/appdata/docker-compose.yml"
        sed -n 'p' "$docker_conf_dir/appdata/$1.yml" >> "$docker_conf_dir/appdata/docker-compose.yml"
        rm -f "$docker_conf_dir/appdata/$1.yml"
        printf '\n%s\n' "Docker compose for $1 downloaded."
    else
        printf '\n%s\n' "There was a problem downloading the compose for $1, try again"
        exit 1
    fi
}

PS3=$'\n'"Please select from the options: "
options=("torrents" "usenet" "both")
printf '\n%s\n\n' "Select your preferred download method."
select opt in "${options[@]}"; do
    case "$opt" in
        "torrents")
            printf '\n%s\n' "You chose torrents, creating data directories..."
            mkdir -p "${mkdir_torrents[@]}"
            printf '\n%s\n\n' "Choose your torrent client:"
            options=("qbittorrent" "qbittorrentvpn" "deluge" "delugevpn" "rtorrentvpn")
            select opt in "${options[@]}"; do
                case $opt in
                    "qbittorrent")
                        printf '\n%s\n\n' "You picked Qbittorrent"
                        get_app_compose "$opt"
                        mkdir -p "$docker_conf_dir/appdata/$opt"
                        break
                        ;;
                    "qbittorrentvpn")
                        printf '\n%s\n\n' "You picked Qbittorrent with VPN"
                        get_app_compose "$opt"
                        mkdir -p "$docker_conf_dir/appdata/$opt"
                        break
                        ;;
                    "deluge")
                        printf '\n%s\n\n' "You picked Deluge"
                        get_app_compose "$opt"
                        mkdir -p "$docker_conf_dir/appdata/$opt"
                        break
                        ;;
                    "delugevpn")
                        printf '\n%s\n\n' "You picked Deluge with VPN"
                        get_app_compose "$opt"
                        mkdir -p "$docker_conf_dir/appdata/$opt"
                        break
                        ;;
                    "rtorrentvpn")
                        printf '\n%s\n\n' "You picked rTorrent with VPN"
                        get_app_compose "$opt"
                        mkdir -p "$docker_conf_dir/appdata/$opt"
                        break
                        ;;
                    *)
                        printf '\n%s\n\n' "invalid option $REPLY"
                        ;;
                esac
            done
            ;;
        "usenet")
            printf '\n%s\n' "You chose usenet, Creating data directories..."
            mkdir -p "${mkdir_usenet[@]}"
            printf '\n%s\n\n' "Choose your usenet client:"
            options=("nzbget" "sabnzbd")
            select opt in "${options[@]}"; do
                case "$opt" in
                    "nzbget")
                        printf '\n%s\n\n' "You picked NZBget"
                        get_app_compose "$opt"
                        mkdir -p "$docker_conf_dir/appdata/$opt"
                        break
                        ;;
                    "sabnzbd")
                        printf '\n%s\n\n' "You picked SABnzbd"
                        get_app_compose "$opt"
                        mkdir -p "$docker_conf_dir/appdata/$opt"
                        break
                        ;;
                    *) printf '\n%s\n\n' "invalid option $REPLY" ;;
                esac
            done
            ;;
        "both")
            printf '\n%s\n' "Creating data directories for torrent and usenet."
            mkdir -p "${mkdir_usenet[@]}" "${mkdir_torrents[@]}"

            printf '\n%s\n\n' "Choose your torrent client:"
            options=("qbittorrent" "qbittorrentvpn" "deluge" "delugevpn" "rtorrentvpn")

            select opt in "${options[@]}"; do
                case $opt in
                    "qbittorrent")
                        printf '\n%s\n\n' "You picked Qbittorrent"
                        get_app_compose "$opt"
                        mkdir -p "$docker_conf_dir/appdata/$opt"
                        break
                        ;;
                    "qbittorrentvpn")
                        printf '\n%s\n\n' "You picked Qbittorrent with VPN"
                        get_app_compose "$opt"
                        mkdir -p "$docker_conf_dir/appdata/$opt"
                        break
                        ;;
                    "deluge")
                        printf '\n%s\n\n' "You picked Deluge"
                        get_app_compose "$opt"
                        mkdir -p "$docker_conf_dir/appdata/$opt"
                        break
                        ;;
                    "delugevpn")
                        printf '\n%s\n\n' "You picked Deluge with VPN"
                        get_app_compose "$opt"
                        mkdir -p "$docker_conf_dir/appdata/$opt"
                        break
                        ;;
                    "rtorrentvpn")
                        printf '\n%s\n\n' "You picked rTorrent with VPN"
                        get_app_compose "$opt"
                        mkdir -p "$docker_conf_dir/appdata/$opt"
                        break
                        ;;
                    *) printf '\n%s\n\n' "invalid option $REPLY" ;;
                esac
            done

            printf '\n%s\n\n' "Choose your usenet client:"
            options=("nzbget" "sabnzbd")
            select opt in "${options[@]}"; do
                case $opt in
                    "nzbget")
                        printf '\n%s\n\n' "You picked NZBget"
                        get_app_compose "$opt"
                        mkdir -p "$docker_conf_dir/appdata/$opt"
                        break
                        ;;
                    "sabnzbd")
                        printf '\n%s\n\n' "You picked SABnzbd"
                        get_app_compose "$opt"
                        mkdir -p "$docker_conf_dir/appdata/$opt"
                        break
                        ;;
                    *)
                        printf '\n%s\n\n' "invalid option $REPLY"
                        ;;
                esac
            done
            break
            ;;
        *)
            printf '\n%s\n\n' "invalid option $REPLY"
            ;;
    esac
    break
done

printf '\n%s\n\n' "Doing final permissions stuff..."
chown -R "$user":"$group" "$docker_data_dir" "$docker_conf_dir"
chmod -R a=,a+rX,u+w,g+w "$docker_data_dir" "$docker_conf_dir"
printf '\n%s\n\n' "Permissions set."

printf '\n%s\n' "Installing Pullio for auto updates..."
if sudo wget -qO /usr/local/bin/pullio "https://raw.githubusercontent.com/hotio/pullio/master/pullio.sh"; then
    sudo chmod +x /usr/local/bin/pullio
    printf '\n%s\n\n' "Pullio installed"
else
    printf '\n%s\n' "There was a problem downloading then /usr/local/bin/pullio, try again"
    exit 1
fi

printf '\n%s\n\n' "Creating task for auto updates..."
if grep -q '/usr/local/bin/pullio' /etc/crontab; then
    sed -e '/\/usr\/local\/bin\/pullio/d' -e '/^$/d' -i.bak-"$(date +%H-%M-%S)" /etc/crontab
else
    cp -f /etc/crontab /etc/crontab.bak-"$(date +%H-%M-%S)"
fi

printf '%s\n' '0    3    *    *    7    root    /usr/local/bin/pullio &>> '"$docker_conf_dir"'/appdata/pullio/pullio.log' >> /etc/crontab
sed 's/    /\t/g' -i /etc/crontab
systemctl -q restart crond
systemctl -q restart synoscheduler
printf '\n%s\n\n' "Task Created"

printf '\n%s\n\n' "Now let's install the containers..."
docker-compose -f "$docker_conf_dir/appdata/docker-compose.yml" up -d
printf '\n%s\n\n' "All set, everything should be running. If you have errors, follow the complete guide. And join our discord server."

exit
