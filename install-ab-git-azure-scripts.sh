#!/bin/bash
# Script to install (clone/download) the GitHub repository with these scripts (azure-scripts-public) on a (Ubuntu) system
#
# NOTE: this script can also be used by a normal (non-root) user

echo
echo "BELEROFONTECH - STARTING CUSTOM 'GIT CLONE AZURE SCRIPTS' INIT!"

# Optional: more debug info (show executed commands)
# set -x

# Define default variable values if missing

# In this script being root is not a requirement, but the behaviour changes a bit
if [[ $( id -u ) != 0 ]]
then
    # The current user (the one that executes the script) should be in the USER env. variable
    [[ -z "$MAINUSER" ]] && [[ ! -z "$USER" ]] && [[ "root" != "$USER" ]] && MAINUSER="$USER"
    [[ -z "$MAINUSER" ]] && echo "Error, cannot automatically set the value for MAINUSER variable. Try using sudo?" && exit 1
else
    # MAINUSER is the preferred/expected var to get the desired value from outside; SUDO_USER can be used also,
    # in case MAINUSER is not defined. If none of the two are defined/available, set a default value: "belero"
    [[ -z "$MAINUSER" ]] && [[ ! -z "$SUDO_USER" ]] && [[ "root" != "$SUDO_USER" ]] && MAINUSER="$SUDO_USER"
    [[ -z "$MAINUSER" ]] && MAINUSER="belero"
fi

echo "Value for MAINUSER variable: $MAINUSER"

sh -xc 'date ; env ; whoami ; pwd'

# Go to the user's HOME dir
cd /home/$MAINUSER
[[ $? -ne 0 ]] && echo "Error, cannot change to the user's HOME dir" && exit 1

echo
git clone https://github.com/Belerofontech/azure-scripts-public
[[ $? -ne 0 ]] && echo "Error, cannot clone the repository" && exit 1

# Fix script permissions, just in case they are not executable
cd azure-scripts-public
find . -name "*.sh" | xargs chmod +x

# Fix owner, if run as sudo
[[ $( id -u ) = 0 ]] && sudo chown -R $MAINUSER:$MAINUSER .

echo
echo "BELEROFONTECH - FINISHED CUSTOM 'GIT CLONE AZURE SCRIPTS' INIT!"

# # Optional: use this to force output to be shown, when run remotely on Azure with "run-custom-script.sh" (making the script exit status != 0 means that it didn't finish successfully)
# echo "FINISHED. Now will end script execution with error status 101..." 1>&2
# exit 101
