#!/bin/bash
# Script to install PostgreSQL 12 (from the official apt repository) on a Ubuntu system
# NOTE: works on Ubuntu in WSL too

# Optional: more debug info (show executed commands)
# set -x

# Define default variable values if missing

[[ -z "$DBUSER" ]] && DBUSER="belero"
echo "Value for DBUSER variable: $DBUSER"

if [[ -z "$DBPASS" ]]
then
    [[ -r ~/.postgresqlpass ]] && DBPASS=$( tail -n1 ~/.postgresqlpass )
    [[ -e ~/.postgresqlpass ]] && [[ -z "$DBPASS" ]] && echo "Invalid DBPASS variable or ~/.postgresqlpass file" && exit 1
fi
echo "Value for DBPASS variable: $DBPASS"

# Get the updated repository information
function OptionalAptGetUpdate()
{
    # Run only if "update-success-stamp" file is present and older than 1 hour (means apt-get update has been run recently, and no apt-get clean afterwards)
    LAST_UPDATED=$( stat --format="%X" /var/lib/apt/periodic/update-success-stamp 2>/dev/null || echo 0 )
    TIME_DIFF=$(( $( date +%s ) - LAST_UPDATED ))
    [[ $TIME_DIFF -gt 3600 ]] && DEBIAN_FRONTEND=noninteractive apt-get -y update
}

# Check for root permissions (user id = 0) and invocation from sudo
if [[ $( id -u ) != 0 ]] || [[ -z "$SUDO_USER" ]]
then
    echo "This script must be run with root privileges, with sudo"
    exit 1
fi

# The first time, generate a random pass and store it in ~/.postgresqlpass
if [[ -z "$DBPASS" ]]
then
    # Generate an easy to type, strong (80 bits of entropy) random password
    # From: https://security.stackexchange.com/questions/71187/one-liner-to-create-passwords-in-linux
    DBPASS=$( od -An -x /dev/urandom 2>/dev/null | tr -d ' \n' 2>/dev/null | head -c20 2>/dev/null )
    [[ -z "$DBPASS" ]] && echo "Error generating random password" && exit 1
    # Save password in the current user's home directory. Do not delete previous values just in case
    echo "$DBPASS" >> ~/.postgresqlpass
    chown $SUDO_USER:$SUDO_USER ~/.postgresqlpass
    chmod 640 ~/.postgresqlpass
fi

# Install pre-requisite packages and get the updated repository information
PREREQ="apt-transport-https lm-sensors"
echo
echo "Installing pre-requisite packages: $PREREQ"
# Run apt-get update only if it hasn't run recently, to save some time
OptionalAptGetUpdate
DEBIAN_FRONTEND=noninteractive apt-get -y install $PREREQ
[[ $? -ne 0 ]] && echo "Error, pre-requisite packages cannot be installed" && exit 1

# PostgreSQL 12 official apt repository. See:
# https://www.postgresql.org/download/linux/ubuntu/
echo
echo "Setting up PostgreSQL repository"
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
wget --quiet -O - 'https://www.postgresql.org/media/keys/ACCC4CF8.asc' | apt-key add -
DEBIAN_FRONTEND=noninteractive apt-get -y update
[[ $? -ne 0 ]] && echo "Error, new repository could not be added (or some other issue happened)" && exit 1

echo
echo "Installing PostgreSQL 12"
DEBIAN_FRONTEND=noninteractive apt-get -y install postgresql-12 postgresql-client-12 postgresql-doc-12 pgtop

# Start the service (in case it has not already been done)
# NOTE: we use service because it works on WSL too (and calls systemctl instead when it has to)
echo
echo "Starting PostgreSQL service"
service postgresql start
sleep 5
# If using systemctl, it uses "less" or other pager to control output interactively, and we don't want that
# Normally we would use systemctl status postgresql --no-pager but in this case "cat" works too...
service postgresql status | cat

cd /  # Avoid problems with home directory permissions when using sudo with non-root users

echo
echo "Creating superuser '$DBUSER'"
sudo -u postgres createuser --superuser "$DBUSER"
[[ $? -ne 0 ]] && echo "Error, user already exists or some other issue happened. Changing password below might fail"

echo
echo "Assigning password '$DBPASS' to superuser '$DBUSER'"
# echo "Running command: ALTER USER $DBUSER WITH PASSWORD '$DBPASS'"
sudo -u postgres psql -c "ALTER USER $DBUSER WITH PASSWORD '$DBPASS'"

echo
echo "Checking PostgreSQL users"
sudo -u postgres psql -c '\du' 2>/dev/null >/dev/null
[[ $? -ne 0 ]] && echo "Error, PostgreSQL not installed or not working?" && exit 1
sudo -u postgres psql -c '\du' | grep " $DBUSER "
[[ $? -ne 0 ]] && echo "Error, PostgreSQL user does not exist?" && exit 1
