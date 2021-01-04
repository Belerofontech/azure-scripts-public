#!/bin/bash
# Script to install the Microsoft ODBC Driver for SQL Server on a Ubuntu system and check the requirements for its use with pyodbc in Python
# Derived from instructions at https://docs.microsoft.com/en-us/sql/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server?view=sql-server-2017
# and https://docs.microsoft.com/en-us/sql/connect/python/pyodbc/step-1-configure-development-environment-for-pyodbc-python-development?view=sql-server-2017
#
# NOTE: using this script implies accepting the license (EULA). See ACCEPT_EULA in the doc and below
# NOTE: works on Ubuntu in WSL too

# Install pre-requisite packages and get the updated repository information
function OptionalAptGetUpdate()
{
    # Run only if "update-success-stamp" file is present and older than 1 hour (means apt-get update has been run recently, and no apt-get clean afterwards)
    LAST_UPDATED=$( stat --format="%X" /var/lib/apt/periodic/update-success-stamp 2>/dev/null || echo 0 )
    TIME_DIFF=$(( $( date +%s ) - LAST_UPDATED ))
    [[ $TIME_DIFF -gt 3600 ]] && DEBIAN_FRONTEND=noninteractive apt-get -y update
}

# Check for root permissions (user id = 0)
if [[ $( id -u ) != 0 ]]
then
    echo "This script must be run with root privileges"
    exit 1
fi

echo
echo "Installing pre-requisite packages apt-transport-https and unixodbc-dev"
# Run apt-get update only if it hasn't run recently, to save some time
OptionalAptGetUpdate
DEBIAN_FRONTEND=noninteractive apt-get -y install apt-transport-https unixodbc-dev
[[ $? -ne 0 ]] && echo "Error, pre-requisite package(s) cannot be installed" && exit 1

AZ_REPO=$(lsb_release -rs)
echo
echo "Adding Microsoft signing key and repository for Ubuntu $AZ_REPO to apt"
# Add the corresponding Microsoft package repository
curl -sf https://packages.microsoft.com/config/ubuntu/$AZ_REPO/prod.list >/dev/null 2>/dev/null
[[ $? -ne 0 ]] && echo "Error, repository not found or network error" && exit 1

# NOTE: tee by default will overwrite the previous file, which is what we want in this case
curl -sf https://packages.microsoft.com/config/ubuntu/$AZ_REPO/prod.list | tee /etc/apt/sources.list.d/mssql-release.list
echo

# Get and add the Microsoft package signing key
curl -sf https://packages.microsoft.com/keys/microsoft.asc | apt-key add -

# Get the updated repository information (in this case it must be done always, since we have added a new repository)
DEBIAN_FRONTEND=noninteractive apt-get -y update

echo
echo "Installing packages from Microsoft repository"
ACCEPT_EULA=Y DEBIAN_FRONTEND=noninteractive apt-get -y install msodbcsql17
[[ $? -ne 0 ]] && echo "Error, package msodbcsql17 cannot be installed" && exit 1

# Optional: install mssql-tools (bcp and sqlcmd)
ACCEPT_EULA=Y DEBIAN_FRONTEND=noninteractive apt-get -y install mssql-tools
[[ $? -ne 0 ]] && echo "Error, package mssql-tools cannot be installed" && exit 1

# Update users path (only if not already done) for mssql-tools
## echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
# Belerofontech: better do it for all users: in /etc/profile instead of in ~/.bashrc
grep -q 'export PATH="$PATH:/opt/mssql-tools/bin"' /etc/profile
if [[ $? -eq 1 ]]
then
    # NOTE: tee by default will overwrite the file, so we add the "-a" parameter to avoid it (and append instead)
    echo | tee -a /etc/profile
    echo '# Belerofontech - Microsoft ODBC Driver for SQL Server' | tee -a /etc/profile
    echo 'export PATH="$PATH:/opt/mssql-tools/bin"' | tee -a /etc/profile
    export PATH="$PATH:/opt/mssql-tools/bin"
fi

echo
echo "Checking for Python module pyodbc"
python3 -m pip show pyodbc && python3 -m pip check pyodbc
# NOTE: this could be made informational only (it is not strictly necessary for the driver itself)
[[ $? -ne 0 ]] && echo "WARNING, Python module pyodbc should be installed too"
