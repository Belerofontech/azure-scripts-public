#!/bin/bash
# Script to install (clone/download) the GitHub repository with these scripts (azure-scripts-public) on a (Ubuntu) system
#
# NOTE: this script no longer can be used by "normal" (non-root) users (...)

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

echo "Value for MAINUSER variable: $MAINUSER"

echo
echo "BELEROFONTECH - STARTING CUSTOM 'GIT CLONE AZURE SCRIPTS' INIT!"

if [[ $( id -u ) = 0 ]]
then
    # Leave trace of this script's output. See: https://unix.stackexchange.com/a/145654
    exec &> >(tee -a /var/log/belero-install-scripts.log)
    chmod -f o-rwx /var/log/belero-install-scripts.log
fi

# Optional: more debug info (show executed commands)
# set -x

sh -xc 'date ; env ; whoami ; pwd'

# Go to the user's HOME dir
cd /home/$MAINUSER
[[ $? -ne 0 ]] && echo "Error, cannot change to the user's HOME dir" && exit 1

echo
git clone https://github.com/Belerofontech/azure-scripts-public
[[ $? -ne 0 ]] && echo "Error, cannot clone the repository" && exit 1

# Fix script permissions, just in case they are not executable
cd azure-scripts-public
find . -type f -name "*.sh" | xargs chmod a+x

# Fix owner, if run as root
[[ $( id -u ) = 0 ]] && chown -R $MAINUSER:$MAINUSER .

echo
echo "BELEROFONTECH - FINISHED CUSTOM 'GIT CLONE AZURE SCRIPTS' INIT!"

# # Optional: use this to force output to be shown, when run remotely on Azure with "run-custom-script.sh" (making the script exit status != 0 means that it didn't finish successfully)
# echo "FINISHED. Now will end script execution with error status 101..." 1>&2
# exit 101
