#!/usr/bin/env sh


usage () {
    you="$(awk -F: '/:1000:1000:/ {print $1}' /etc/passwd)"
    ip="$(ip address show dev "$(ip route show default | awk '{print $5}')" | awk '/inet / {gsub("255", "", $4);print $4}')"
    printf '\nUsage: %s --new-username <New_Username> --host-id <Number> \n' "$0" >&2
    printf '\t-u, --new-username        Rename the user with UID 1000: %s -> New_Username\n' "${you}" >&2
    printf '\t-i, --host-id             Set a static IP Address. %s<Number>\n' "${ip}" >&2
    printf '\t-h|-?: print this help\n' >&2
    unset you ip
}


# Parse command-line options
while [ $# -gt 0 ]; do
    case "$1" in
        '-i'|'--host-id')
            host_id="$2"
            shift 2  # Shift by 2 to consume both the option and its value
            ;;

        '-u'|'--new-username')
            new_username="$2"
            shift 2  # Shift by 2 to consume both the option and its value
            ;;

        *)
            usage && exit 1
            ;;
    esac
done

# Check if the required options are provided
if [ -z "$host_id" ] || [ -z "$new_username" ]; then
    echo "Both --new-username and --host-id options are required."
    usage && exit 1
fi










# ----------------------------------------------- Reorganize .list files ------------------------------------------------
reorganize_dot_list_files() {

    if [ ! -e /etc/apt/sources.list.d/debian.list ] || [ ! -e /etc/apt/sources.list.d/debian-stable-updates.list ]; then
        # ------------------------------------------------- source.list -------------------------------------------------
        cat << 'HereDoc' > /etc/apt/sources.list
# This file is empty by default.  Sources are under /etc/apt/souces.list.d


HereDoc



        # ------------------------------------------------- debian.list -------------------------------------------------
        cat << 'HereDoc' > /etc/apt/sources.list.d/debian.list
# Debian Stable.


# Debian Bookworm, main repository + contrib packages + non-free packages + non-free firmware
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
#deb-src http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware


# Debian Bookworm, security updates + contrib packages + non-free packages + non-free firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
#deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware


# Debian Bookworm backports, main repository + contrib packages + non-free packages + non-free firmware
deb http://deb.debian.org/debian/ bookworm-backports main contrib non-free non-free-firmware
# bookworm-updates, to get updates before a point release is made;
# see https://www.debian.org/doc/manuals/debian-reference/ch02.en.html#_updates_and_backports


HereDoc



        # ----------------------------------------- debian-stable-updates.list ------------------------------------------
        cat << 'HereDoc' > /etc/apt/sources.list.d/debian-stable-updates.list
# Debien Bookworm Updates

# Debian Bookworm, "volatile" updates main repository + contrib packages + non-free packages + non-free firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
# Comment the next line with '#' if it causes an error:
deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware


HereDoc



        # ------------------------------------------------- cat *.list --------------------------------------------------
        cat << HereDoc | bash
# Customize Prompt Shell 4 (with blue color) '[yyyy-mm-dd hh꞉mm꞉ss.mil] >>> '
PS4="$(printf '\n%b' "\033[1;34m[$(date +%Y-%m-%d\ %H꞉%M꞉%S.%3N)] \033[1;34m>>>\033[0m ")"
set -x

# clear

# See the content of the modified files
cat /etc/apt/sources.list
cat /etc/apt/sources.list.d/debian.list
cat /etc/apt/sources.list.d/debian-stable-updates.list

HereDoc



    fi

}
reorganize_dot_list_files










# ---------------------------------------------- Install Missing Packages -----------------------------------------------
install_missing_pkgs (){
    _required_pkgs="$*"

    _installed_pkgs=";$(dpkg-query --show --showformat='${binary:Package};')"
    _missing_pkgs=""

    _TARGET_USER="$(awk -F: '/:1000:1000:/ {print $1}' /etc/passwd)"
    _TARGET_GROUP=";$(groups "${_TARGET_USER}" | tr ' ' ';');"

    # ---------------------------------------- filtering non-installed Packages -----------------------------------------
    for _package_name in ${_required_pkgs}; do
        # If the required pkg is not found in the installed packages list (regex in posix shell)
        if [ "$(expr "${_installed_pkgs}" : ".*;${_package_name};")" -eq 0 ]; then
            # then add the package_name to the missing packages
            _missing_pkgs="${_missing_pkgs} ${_package_name}"


            # ---------------------------------- Preparing a Group list for the $USER -----------------------------------
            # if the user is part of specific groups then add them to _MISSING_GROUPS list (separated with comma ',') 
            case "$_package_name" in
            "sudo")
                    # Check if the user is part of 'sudo' group without generating error:
                    if  [ "$(expr "${_TARGET_GROUP}" : ".*;sudo;")" -eq 0 ] ; then
                        # if _MISSING_GROUPS is NOT empty,
                        # then append a comma (',') to the current value of _MISSING_GROUPS:
                        _MISSING_GROUPS="${_MISSING_GROUPS:+$_MISSING_GROUPS,}sudo"
                    fi
                ;;

            "docker-ce"|"docker-ce-cli"|"containerd.io"|"docker-buildx-plugin"|"docker-compose-plugin")
                    # Check if the user is part of 'docker' group without generating error:
                    if  [ "$(expr "${_TARGET_GROUP}${_MISSING_GROUPS};" : ".*;docker;")" -eq 0 ] ; then
                        # if _MISSING_GROUPS is NOT empty,
                        # then append a comma (',') to the current value of _MISSING_GROUPS:
                        _MISSING_GROUPS="${_MISSING_GROUPS:+$_MISSING_GROUPS,}docker"
                    fi
                ;;
            esac
            # -----------------------------------------------------------------------------------------------------------
        fi


        # if [ "$(expr ";openssh-server;rsync;sudo;" :  ".*;${_package_name};")" -eq 0 ]; then
        #     printf '#!/usr/bin/env sh\nexit 0\n' >
        # fi
    done
    # -------------------------------------------------------------------------------------------------------------------


    # ------------------------------------------- Installing Missing Packages -------------------------------------------
    if [ -n "${_missing_pkgs## }" ]; then

        # Update the local package repository information:
        apt-get update

        # If the '/.dockerenv' or '.dockerinit' exist
        if [ -f "/.dockerenv" ] || [ -f "/.dockerinit" ]; then
            # That means, we are "Inside a Docker container"

            # Fix "debconf: (Can't locate Term/ReadLine.pm in @INC" with: DEBIAN_FRONTEND=noninteractive
            # Error caused by the following Packages: ca-certificates locales man-db openssh-server tzdata
            export DEBIAN_FRONTEND
            DEBIAN_FRONTEND=noninteractive

            # Needed for docker containers
            _NO_RECOMMENDS_IF_INSIDE_A_CONTAINER='--no-install-recommends'

        fi

        _GREEN_COLOR='\033[32m'
        _BLUE_COLOR='\033[34m'
        _NO_COLOR='\033[0m'
        # If the list of missing packages is non-zero length (Not empty)
        for _pkg in ${_missing_pkgs## }; do

            # Display a message indicating the installation of the package:
            printf "${_GREEN_COLOR}Installing ${_BLUE_COLOR}%s${_GREEN_COLOR} package...${_NO_COLOR}\n" "${_pkg}"

            # Installing the current package:
            apt-get install "${_NO_RECOMMENDS_IF_INSIDE_A_CONTAINER}" --assume-yes "${_pkg}"

            # Print a successful installation message:
            printf "${_GREEN_COLOR}The ${_BLUE_COLOR}%s${_GREEN_COLOR} package have been installed successfully.${_NO_COLOR}\n\n" "${_pkg}"
        done

        # Unset environment variables used during package installation
        unset DEBIAN_FRONTEND _NO_RECOMMENDS_IF_INSIDE_A_CONTAINER _GREEN_COLOR _BLUE_COLOR _NO_COLOR _pkg
    fi

    # Clear package-related variables:
    unset _required_pkgs _installed_pkgs _missing_pkgs _TARGET_USER _TARGET_GROUP _package_name
}
install_missing_pkgs "ca-certificates curl jq less locales man-db most mtr nano openssh-server procps rsync sudo tzdata vim whois"










# ---------------------------------------------------- Install Ngrok ----------------------------------------------------
install_ngrok(){
    if [ ! -x '/usr/local/bin/ngrok' ]; then
        # Download the Ngrok binary from the specified URL
        # and saves it in the current directory with ('-O' option) the original name.
        curl -O https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz


        # extracts the downloaded Ngrok archive into '/usr/local/bin' directory:
        tar xvzf ./ngrok-v3-stable-linux-amd64.tgz -C /usr/local/bin


        # removes any files in the current directory that start with "ngrok"
        rm ngrok*
    fi
}
install_ngrok










# ------------------------------------------------ Install Docker Engine ------------------------------------------------
install_docker_engine(){

    # ------------------------------------------- Install Essential Packages --------------------------------------------
    # Install "ca-certificates curl gnupg" in not installed yet:
    install_missing_pkgs "ca-certificates curl gnupg"



    # ------------------------------------------ Add Docker's official GPG key ------------------------------------------
    # Creates the /etc/apt/keyrings directory with
    #   read, write, and execute permissions for the owner (root)
    #   and read and execute permissions for others.
    # It's where the APT keyring will be stored.
    install -m 0755 -d /etc/apt/keyrings


    # Determines the Linux distribution's ID by extracting the value of
    #   the ID field from the /etc/*release (e.g., "debian" for Debian or "ubuntu" for Ubuntu)
    _DISTRO_ID="$(awk -F= '/^ID=/ {print $2}' /etc/*release)"


    # Download the Docker GPG key for the specific Linux distribution, then de-armor the GPG key
    #   and saves it as a binary file in the /etc/apt/keyrings directory with the name "docker.gpg"
    curl -fsSL "https://download.docker.com/linux/${_DISTRO_ID}/gpg" | \
        gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg


    # Changes the permissions of the "docker.gpg" file
    #   to make it readable by all users (owner, group, and others).
    chmod a+r /etc/apt/keyrings/docker.gpg



    # ---------------------------------------- Add the repository to Apt sources ----------------------------------------
    # Determines the codename (e.g., "jammy" for Ubuntu or "bookworm" for Debian)
    #   of the Ubuntu or Debian version currently running on the system
    #   by extracting the value of the VERSION_CODENAME field from the /etc/*release.
    _VERSION_CODENAME="$(awk -F= '/^VERSION_CODENAME=/ {print $2}' /etc/os-release)"


    # Capitalize the 1st character of each word (e.g., "Debian Bookworm" or "Ubuntu Jammy"):
    _DISTRO="$(echo "${_DISTRO_ID} ${_VERSION_CODENAME}" | sed 's/\b\w/\U&/g')"


    # Retrieves system's architecture (whether the system is 32-bit or 64-bit):
    _ARCH="$(dpkg --print-architecture)" 


    # Add Docker APT repository source line to system sources:
    cat << HereDoc > /etc/apt/sources.list.d/docker.list
# Docker APT repository for ${_DISTRO} (stable) on ${_ARCH} architecture, using a GPG key for secure package verification:
deb [arch=${_ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${_DISTRO_ID} ${_VERSION_CODENAME} stable
HereDoc



    # --------------------------------------------- Install Docker Packages ---------------------------------------------
    # Install Docker Packages if not installed yet:
    install_missing_pkgs "docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"


    # ------------------------------------------------ Cleanup Variables ------------------------------------------------
    # Unsetting distribution-specific variables:
    unset _DISTRO_ID _VERSION_CODENAME



    # ------------------------------------------- Official Installation Guide -------------------------------------------
    # See:
    # https://docs.docker.com/engine/install/debian/
    # https://docs.docker.com/engine/install/ubuntu/
}
install_docker_engine










# ----------------------------------------- [root] Renaming user (+sudo group) ------------------------------------------
rename_user(){



    # ------------------------------------- Getting Old User name & Old Group name --------------------------------------
    # Extract the username where UID is 1000 and GID is 1000.
    _OLD_USERNAME="$(awk -F: '/:1000:1000:/ {print $1}' /etc/passwd)"
    # Use 'id' command to get the group name associated with '_OLD_USERNAME'.
    _OLD_GROUPNAME="$(id "${_OLD_USERNAME}" --group --name)"


    # ------------------------------------- Setting NEW User name & NEW Group name --------------------------------------
    # Set the new username and group name to the provided new_username value.
    _NEW_USERNAME="${new_username}"
    _NEW_GROUPNAME="${new_username}"


    # Check if the old username is not equal to the new username
    # or if the old group name is not equal to the new group name.
    if [ "${_OLD_USERNAME}" != "${_NEW_USERNAME}" ] || [ "${_OLD_GROUPNAME}" != "${_NEW_GROUPNAME}" ]; then

        # -------------------------------------------- Rename the User name ---------------------------------------------
        # Modify user attributes: rename the user, moves their home directory, and appends them to missing groups.
        /sbin/usermod "${_OLD_USERNAME}" \
            --badnames --login "${_NEW_USERNAME}" \
            --comment "${_NEW_USERNAME},,," \
            --move-home --home "/home/${_NEW_USERNAME}" \
            --append --groups "${_MISSING_GROUPS}" \
            --shell /bin/bash
        _RENAME_USERNAME_EXIT_CODE="$?"


        # -------------------------------------------- Rename the Group name --------------------------------------------
        # Rename the old group to the new group name.
        /sbin/groupmod "${_OLD_GROUPNAME}" --new-name "${_NEW_GROUPNAME}"
        _RENAME_GROUP_EXIT_CODE="$?"


        # ----------------------------------------- Print a Successful Message ------------------------------------------
        # Check if both user and group renaming were successful (exit codes are 0) and provide a success message.
        if [ "${_RENAME_USERNAME_EXIT_CODE}" -eq 0 ] && [ "${_RENAME_GROUP_EXIT_CODE}" -eq 0 ]; then
            echo "User Renamed Successfully !"
        fi

    else
        # ------------------------------------------------- Do nothing --------------------------------------------------
        # If this script is executed again, no need to rename it again.
        echo "User already renamed to ${_NEW_USERNAME}."

    fi

    # After renaming user and group, remove the values assigned to the variables:
    unset _NEW_USERNAME _OLD_USERNAME _OLD_GROUPNAME _NEW_GROUPNAME _MISSING_GROUPS _RENAME_USERNAME_EXIT_CODE _RENAME_GROUP_EXIT_CODE
}
rename_user









# ------------------------------------------------ Set static IP Address ------------------------------------------------
set_static_ip_address(){


    # Current interface name:
    _INTERFACE_NAME="$(ip route show default | awk '{print $5}')"


    # Check if the network configuration file for the given interface does not exist
    if [ ! -e "/etc/network/interfaces.d/${_INTERFACE_NAME}" ]; then

        # ------------------------------------------- Convert cidr to netmask -------------------------------------------
        # Retrieve only the Network ID (without the host part): (e.g.: 192.168.1.)
        # (the gsub function removes the last 255 from "192.168.1.255" and the awk returns only "192.168.1.") 
        _IP_NETWORK="$(ip address show dev "${_INTERFACE_NAME}" | awk '/inet / {gsub("255", "", $4);print $4}')"


        # Define a Static IP Address (e.g.: 192.168.1.100):
        _NEW_IP_ADDRESS="${_IP_NETWORK}${host_id}"



        # ------------------------------------------- Convert CIDR to Netmask -------------------------------------------
        # Retrieve CIDR notation (e.g.: 192.168.1.0/24 -> 24):
        _cidr="$(ip r | awk -v interface_name="${_INTERFACE_NAME}" '!/default/ && $0 ~ interface_name { split($1, cidr, "/"); print cidr[2] }')"


        # Calculate the subnet mask value based on the CIDR notation using the bitwise operations:
        # (e.g: 24 -> 4294967040)
        _val="$(( 0xffffffff ^ ((1 << (32 - _cidr)) - 1) ))"


        # Calculate the subnet mask in IP address format from the numerical subnet mask into the familiar format:
        # (e.g: 4294967040 -> '255.255.255.0')
        _NETMASK_IP="$((_val >> 24 & 0xff)).$((_val >> 16 & 0xff)).$((_val >> 8 & 0xff)).$((_val & 0xff))"


        # Clean up temporary variables after calculating the subnet mask, these temporary variables are no longer needed,
        # so they are unset to free up system resources.
        unset _cidr _val



        # --------------------------------------------- Gateway IP Address ----------------------------------------------
        # Retrieve the Gateway IP Address:
        # (e.g: 192.168.1.1)
        _GATEWAY_IP="$(ip route | awk '/^default/ {print $3}')"



        # --------------------------------------------- Gateway IP Address ----------------------------------------------
        # Creates a new configuration file for Wifi (e.g: enp0s3)
        cat << HereDoc > "/etc/network/interfaces.d/${_INTERFACE_NAME}" && cat "/etc/network/interfaces.d/${_INTERFACE_NAME}"


iface ${_INTERFACE_NAME} inet static
      address ${_NEW_IP_ADDRESS}
      netmask ${_NETMASK_IP}
      gateway ${_GATEWAY_IP}

# Source:
# https://linuxconfig.org/how-to-setup-a-static-ip-address-on-debian-linux

HereDoc



        # ------------------------------------------------ Disable dhcp -------------------------------------------------
        # Commenting out DHCP configuration for the specified interface.
        sed -Ei "s|^(iface ${_INTERFACE_NAME} inet dhcp)|#\1|g" /etc/network/interfaces


    else
        # ------------------------------------------------- Do nothing --------------------------------------------------
        echo "The ${_INTERFACE_NAME}'s Network Interface is already configured under '/etc/network/interfaces.d/${_INTERFACE_NAME}':"
        cat "/etc/network/interfaces.d/${_INTERFACE_NAME}"

    fi

    # Remove the values assigned to the variables:
    unset _INTERFACE_NAME _IP_NETWORK _NEW_IP_ADDRESS host_id _NETMASK_IP _GATEWAY_IP
}
set_static_ip_address










# --------------------------------------------- Disable SSH PermitRootLogin ---------------------------------------------
disable_SSH_PermitRootLogin(){
    # Remove all lines that starts with "PermitRootLogin yes":
    sed -i '/^PermitRootLogin yes/d' /etc/ssh/sshd_config
}
disable_SSH_PermitRootLogin



