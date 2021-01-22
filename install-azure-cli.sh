#!/bin/bash
# Script to install the Azure CLI 2.0 on a Ubuntu (18.04) system

# Get the updated repository information
function OptionalAptGetUpdate()
{
    # Run only if "update-success-stamp" file is present and older than 1 hour (means apt-get update has been run recently, and no apt-get clean afterwards)
    LAST_UPDATED=$( stat --format="%X" /var/lib/apt/periodic/update-success-stamp 2>/dev/null || echo 0 )
    TIME_DIFF=$(( $( date +%s ) - LAST_UPDATED ))
    [[ $TIME_DIFF -gt 3600 ]] && apt-get -y update
}

# Check for root permissions (user id = 0)
if [[ $( id -u ) != 0 ]]
then
    echo "This script must be run with root privileges"
    exit 1
fi

echo
echo "BELEROFONTECH - STARTING AZURE CLI INSTALL SCRIPT"

# Leave trace of this script's output. See: https://unix.stackexchange.com/a/145654
exec &> >(tee -a /var/log/belero-install-scripts.log)
chmod -f o-rwx /var/log/belero-install-scripts.log

# Optional: more debug info (show executed commands)
# set -x

sh -xc 'date ; env ; whoami ; pwd'

# Avoid apt-get commands to ask config/setup questions interactively (Debian/Ubuntu)
export DEBIAN_FRONTEND=noninteractive

# Install pre-requisite packages and get the updated repository information
PREREQ="apt-transport-https"
echo "Installing pre-requisite package(s): $PREREQ"
# Run apt-get update only if it hasn't run recently, to save some time
OptionalAptGetUpdate
apt-get -y install $PREREQ
[[ $? -ne 0 ]] && echo "Error, pre-requisite package(s) cannot be installed" && exit 1

AZ_REPO=$(lsb_release -cs)
echo "Adding Microsoft signing key and repository for Ubuntu $AZ_REPO to apt"
# Add the corresponding Microsoft package repository
# NOTE: tee by default will overwrite the previous file, which is what we want in this case
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | tee /etc/apt/sources.list.d/azure-cli.list

# Get and add the Microsoft package signing key
curl -sf https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
[[ $? -ne 0 ]] && echo "Error, Microsoft package signing key cannot be added" && exit 1

# Get the updated repository information (in this case it must be done always, since we have added a new repository)
apt-get -y update

echo "Installing package from Microsoft repository"
apt-get -y install azure-cli

# Check that it is installed OK, and show version info
sudo -E -u $MAINUSER az --version

echo
echo "BELEROFONTECH - FINISHED AZURE CLI INSTALL SCRIPT"

# # Optional: use this to force output to be shown, when run remotely on Azure with "run-custom-script.sh" (making the script exit status != 0 means that it didn't finish successfully)
# echo "FINISHED. Now will end script execution with error status 101..." 1>&2
# exit 101
