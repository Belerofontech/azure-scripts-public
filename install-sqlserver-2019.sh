#!/bin/bash
# Script to install Microsoft SQL Server 2019 (Express) on a Ubuntu (18.04) system
# Derived from instructions at https://docs.microsoft.com/en-us/sql/linux/quickstart-install-connect-ubuntu?view=sql-server-linux-ver15
# and https://docs.microsoft.com/en-us/sql/linux/sample-unattended-install-ubuntu?view=sql-server-linux-ver15
#
# NOTE: using this script implies accepting the license (EULA). See ACCEPT_EULA in the doc and below
# NOTE: does NOT work on Ubuntu in WSL!

# Optional: more debug info (show executed commands)
# set -x

# Define default variable values if missing

# MAINUSER is the preferred/expected var to get the desired value from outside; SUDO_USER can be used also,
# in case MAINUSER is not defined. If none of the two are defined/available, set a default value: "belero"
[[ -z "$MAINUSER" ]] && [[ ! -z "$SUDO_USER" ]] && [[ "root" != "$SUDO_USER" ]] && MAINUSER="$SUDO_USER"
[[ -z "$MAINUSER" ]] && MAINUSER="belero"
echo "Value for MAINUSER variable: $MAINUSER"

[[ -z "$DBUSER" ]] && DBUSER="$MAINUSER"
echo "Value for DBUSER variable: $DBUSER"

if [[ -z "$DBPASS" ]]
then
    [[ -r ~/.sqlserverpass ]] && DBPASS=$( tail -n1 ~/.sqlserverpass )
    [[ -e ~/.sqlserverpass ]] && [[ -z "$DBPASS" ]] && echo "Invalid DBPASS variable or ~/.sqlserverpass file" && exit 1
fi
echo "Value for DBPASS variable: $DBPASS"

# Get the updated repository information
function OptionalAptGetUpdate()
{
    # Run only if "update-success-stamp" file is present and older than 1 hour (means apt-get update has been run recently, and no apt-get clean afterwards)
    LAST_UPDATED=$( stat --format="%X" /var/lib/apt/periodic/update-success-stamp 2>/dev/null || echo 0 )
    TIME_DIFF=$(( $( date +%s ) - LAST_UPDATED ))
    [[ $TIME_DIFF -gt 3600 ]] && apt-get -y update
}

function insideWSL()
{
    case "$(uname -r)" in
    *microsoft* ) true ;; # WSL 2
    *Microsoft* ) true ;; # WSL 1
    * ) false;;
    esac
}

# Check for root permissions (user id = 0)
if [[ $( id -u ) != 0 ]]
then
    echo "This script must be run with root privileges"
    exit 1
fi

# Check for WSL
if insideWSL
then
    echo "Microsoft SQL Server 2019 is not supported on WSL"
    exit 1
fi

# Avoid apt-get commands to ask config/setup questions interactively (Debian/Ubuntu)
export DEBIAN_FRONTEND=noninteractive

# The first time, generate a random pass and store it in ~/.sqlserverpass
if [[ -z "$DBPASS" ]]
then
    # Generate an easy to type, strong (80 bits of entropy) random password
    # From: https://security.stackexchange.com/questions/71187/one-liner-to-create-passwords-in-linux
    # NOTE: SQL Server requires "strong" passwords with 3 of: uppercase, lowercase, numbers and special chars
    # DBPASS=$( od -An -x /dev/urandom 2>/dev/null | tr -d ' \n' 2>/dev/null | head -c20 2>/dev/null )
    DBPASS=$( base64 -w20 /dev/urandom 2>/dev/null | grep -e "+\|/" | head -n1 2>/dev/null )
    [[ -z "$DBPASS" ]] && echo "Error generating random password" && exit 1
    # Save password in the current user's home directory. Do not delete previous values just in case
    echo "$DBPASS" >> ~/.sqlserverpass
    chown $MAINUSER:$MAINUSER ~/.sqlserverpass
    chmod 640 ~/.sqlserverpass
fi

# Install pre-requisite packages and get the updated repository information
# TO-DO: check; unixodbc-dev is really needed?
PREREQ="apt-transport-https unixodbc-dev"
echo
echo "Installing pre-requisite packages: $PREREQ"
# Run apt-get update only if it hasn't run recently, to save some time
OptionalAptGetUpdate
apt-get -y install $PREREQ
[[ $? -ne 0 ]] && echo "Error, pre-requisite package(s) cannot be installed" && exit 1

AZ_REPO=$(lsb_release -rs)
echo
echo "Adding Microsoft signing key and repository for Ubuntu $AZ_REPO to apt"
# Add the corresponding Microsoft package repository
curl -sf https://packages.microsoft.com/config/ubuntu/$AZ_REPO/mssql-server-2019.list >/dev/null 2>/dev/null
[[ $? -ne 0 ]] && echo "Error, repository not found or network error" && exit 1

# NOTE: tee by default will overwrite the previous file, which is what we want in this case
curl -sf https://packages.microsoft.com/config/ubuntu/$AZ_REPO/mssql-server-2019.list | tee /etc/apt/sources.list.d/mssql-release.list
echo

# Get and add the Microsoft package signing key
curl -sf https://packages.microsoft.com/keys/microsoft.asc | apt-key add -

# Get the updated repository information (in this case it must be done always, since we have added a new repository)
apt-get -y update

echo
echo "Installing packages from Microsoft repository"
ACCEPT_EULA=Y apt-get -y install mssql-server
[[ $? -ne 0 ]] && echo "Error, package mssql-server cannot be installed" && exit 1

echo
systemctl stop mssql-server --no-pager

# If using systemctl, it uses "less" or other pager to control output interactively, and we don't want that
# We can use the --no-pager option (in other cases, redirecting to "cat" works too...)
# service mssql-server status | cat
systemctl status mssql-server --no-pager

echo
echo "Installation finished. Now running the following command to set-up the server:"
echo "  sudo /opt/mssql/bin/mssql-conf setup"

# MSSQL_PID: Product ID of the version of SQL server you're installing
#   Must be evaluation, developer, express, web, standard, enterprise, or your 25 digit product key
# MSSQL_SA_PASSWORD: Password for the SA user (required)
ACCEPT_EULA=Y MSSQL_SA_PASSWORD=$DBPASS MSSQL_PID=express /opt/mssql/bin/mssql-conf -n setup accept-eula

echo
echo "Optional (recommended): install mssql-tools package (bcp and sqlcmd), for instance by running:"
echo "  sudo install-sqlserver-odbc-driver.sh"
echo "Also, remember to configure firewall(s) to allow traffic to TCP port 1433..."
# Setup Ubuntu local firewall (disabled by default)
# sudo ufw allow 1433/tcp
# sudo ufw reload

# # Optional (recommended): install mssql-server-agent
# # TO-DO: fix, the package is no longer available?
# echo
# echo "Installing SQL Server Agent from Microsoft repository"
# apt-get -y install mssql-server-agent

echo
echo "Restarting SQL Server..."
systemctl restart mssql-server --no-pager
sleep 5

# service mssql-server status | cat
systemctl status mssql-server --no-pager

# # Optional: use this to force output to be shown, when run remotely on Azure with "run-custom-script.sh" (making the script exit status != 0 means that it didn't finish successfully)
# echo "FINISHED. Now will end script execution with error status 101..." 1>&2
# exit 101
