#!/bin/bash
# Script to install Python (3.x) packages with pip on a Ubuntu (18.04) system
#
# Based on the previous cloud-config.txt file (runcmd section) from the former "vm-ubuntuserver-1804" template (...)

# Define default variable values if missing

# MAINUSER is the preferred/expected var to get the desired value from outside; SUDO_USER can be used also,
# in case MAINUSER is not defined. If none of the two are defined/available, set a default value: "belero"
[[ -z "$MAINUSER" ]] && [[ ! -z "$SUDO_USER" ]] && [[ "root" != "$SUDO_USER" ]] && MAINUSER="$SUDO_USER"
[[ -z "$MAINUSER" ]] && MAINUSER="belero"
echo "Value for MAINUSER variable: $MAINUSER"

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

echo "NOTE: this script is deprecated, and should be used only for testing"
echo "You should better use a Python virtual env and requirements.txt files!"
echo
echo "YOU CAN CANCEL WITH CTRL-C IN THE NEXT 60 SECONDS!"
sleep 60

echo
echo "BELEROFONTECH - STARTING PIP PACKAGES INSTALL SCRIPT!"

# Leave trace of this script's output. See: https://unix.stackexchange.com/a/145654
exec &> >(tee -a /var/log/belero-install-scripts.log)
chmod -f o-rwx /var/log/belero-install-scripts.log

# Optional: more debug info (show executed commands)
# set -x

sh -xc 'date ; env ; whoami ; pwd'

# Avoid apt-get commands to ask config/setup questions interactively (Debian/Ubuntu)
export DEBIAN_FRONTEND=noninteractive

sh -xc 'date ; env ; whoami ; pwd'

# Install pre-requisite packages and get the updated repository information
PREREQ="apt-transport-https python3-pip python3-venv python3-wheel unixodbc-dev mdbtools"
echo
echo "Installing pre-requisite package(s): $PREREQ"
# Run apt-get update only if it hasn't run recently, to save some time
OptionalAptGetUpdate
apt-get -y install $PREREQ
[[ $? -ne 0 ]] && echo "Error, pre-requisite package(s) cannot be installed" && exit 1

echo
# Optional: update Python pip (but not to 20.3 version or later, which has big changes in dependency management!)
sudo -E -u $MAINUSER python3 -m pip install --user --upgrade 'pip<20.3'

echo
# Install desired Python packages with pip (user mode!)
sudo -E -u $MAINUSER python3 -m pip install --user pandas pyomo xlwt xlrd openpyxl matplotlib pillow scipy statsmodels xlsxwriter pyodbc sqlalchemy pymysql pandas_access
# TO-DO: check; this package fails to install!
# sudo -E -u $MAINUSER python3 -m pip install --user streamlit
# TO-DO: check; this package fails to install!
# sudo -E -u $MAINUSER python3 -m pip install --user pandas_profiling

# Check that all dependencies are OK
echo
sudo -E -u $MAINUSER python3 -m pip check

echo
echo "BELEROFONTECH - FINISHED PIP PACKAGES INSTALL SCRIPT!"

# # Optional: use this to force output to be shown, when run remotely on Azure with "run-custom-script.sh" (making the script exit status != 0 means that it didn't finish successfully)
# echo "FINISHED. Now will end script execution with error status 101..." 1>&2
# exit 101
