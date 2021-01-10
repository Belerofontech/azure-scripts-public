#!/bin/bash
# Script to install the desired basic packages and do the initial setup on a Ubuntu (18.04) system
#
# Based on the previous cloud-config.txt file (runcmd section) from the former "vm-ubuntuserver-1804" template (...)

echo
echo "BELEROFONTECH - STARTING CUSTOM 'BASIC' INIT!"

# Optional: more debug info (show executed commands)
# set -x

# Define default variable values if missing

# MAINUSER is the preferred/expected var to get the desired value from outside; SUDO_USER can be used also,
# in case MAINUSER is not defined. If none of the two are defined/available, set a default value: "belero"
[[ -z "$MAINUSER" ]] && [[ ! -z "$SUDO_USER" ]] && [[ "root" != "$SUDO_USER" ]] && MAINUSER="$SUDO_USER"
[[ -z "$MAINUSER" ]] && MAINUSER="belero"
echo "Value for MAINUSER variable: $MAINUSER"

# Check for root permissions (user id = 0)
if [[ $( id -u ) != 0 ]]
then
    echo "This script must be run with root privileges"
    exit 1
fi

# Avoid apt-get commands to ask config/setup questions interactively (Debian/Ubuntu)
export DEBIAN_FRONTEND=noninteractive

sh -xc 'date ; env ; whoami ; pwd'

# More secure permissions for main user's HOME dir
chmod 0750 /home/$MAINUSER

# Update the repositories' package lists, and upgrade the installed packages!
apt-get -y update && apt-get -y -u dist-upgrade

# General system tools/utilities packages that we want to be always installed
apt-get -y install apt-transport-https ca-certificates curl cifs-utils dos2unix colorized-logs ccze byobu gdb zip unzip bc vim neofetch
# Pyhton-specific packages
apt-get -y install python3-pip python3-venv python3-wheel unixodbc-dev mdbtools
# # Optional: install Cbc and GLPK solvers
# apt-get -y install coinor-cbc glpk-utils

# # Optional: Remove Python 2 and set Python 3 as the default for scripts that use just "python". From:
# # https://stackoverflow.com/a/50331137
# apt-get -y remove python2.7-minimal python-minimal
# # TO-DO: check, the following line is not needed really...
# # update-alternatives --remove python /usr/bin/python2
# update-alternatives --install /usr/bin/python python /usr/bin/python3 10
# update-alternatives --set python /usr/bin/python3

echo
echo "BELEROFONTECH - FINISHED CUSTOM 'BASIC' INIT!"

# # Optional: use this to force output to be shown, when run remotely on Azure with "run-custom-script.sh" (making the script exit status != 0 means that it didn't finish successfully)
# echo "FINISHED. Now will end script execution with error status 101..." 1>&2
# exit 101
