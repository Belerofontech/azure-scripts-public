#!/bin/bash
# Script to install PostgreSQL 12 (from the official apt repository) on a Ubuntu (18.04) system

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
    [[ -r /home/$MAINUSER/.postgresqlpass ]] && DBPASS=$( tail -n1 /home/$MAINUSER/.postgresqlpass )
    [[ -e /home/$MAINUSER/.postgresqlpass ]] && [[ -z "$DBPASS" ]] && echo "Invalid DBPASS variable or /home/$MAINUSER/.postgresqlpass file" && exit 1
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

# Check for root permissions (user id = 0)
if [[ $( id -u ) != 0 ]]
then
    echo "This script must be run with root privileges"
    exit 1
fi

echo
echo "BELEROFONTECH - STARTING POSTGRESQL INSTALL SCRIPT!"

# Leave trace of this script's output. See: https://unix.stackexchange.com/a/145654
exec &> >(tee -a /var/log/belero-install-scripts.log)
chmod -f o-rwx /var/log/belero-install-scripts.log

# Optional: more debug info (show executed commands)
# set -x

sh -xc 'date ; env ; whoami ; pwd'

# Avoid apt-get commands to ask config/setup questions interactively (Debian/Ubuntu)
export DEBIAN_FRONTEND=noninteractive

# The first time, generate a random pass and store it in ~/.postgresqlpass
if [[ -z "$DBPASS" ]]
then
    # Generate an easy to type, strong (80 bits of entropy) random password
    # From: https://security.stackexchange.com/questions/71187/one-liner-to-create-passwords-in-linux
    DBPASS=$( od -An -x /dev/urandom 2>/dev/null | tr -d ' \n' 2>/dev/null | head -c20 2>/dev/null )
    [[ -z "$DBPASS" ]] && echo "Error generating random password" && exit 1
    # Save password in the current user's home directory. Do not delete previous values just in case
    echo "$DBPASS" >> /home/$MAINUSER/.postgresqlpass
    chown $MAINUSER:$MAINUSER /home/$MAINUSER/.postgresqlpass
    chmod 640 /home/$MAINUSER/.postgresqlpass
fi

# Install pre-requisite packages and get the updated repository information
PREREQ="apt-transport-https lm-sensors"
echo
echo "Installing pre-requisite package(s): $PREREQ"
# Run apt-get update only if it hasn't run recently, to save some time
OptionalAptGetUpdate
apt-get -y install $PREREQ
[[ $? -ne 0 ]] && echo "Error, pre-requisite package(s) cannot be installed" && exit 1

# PostgreSQL 12 official apt repository. For more info see:
# https://www.postgresql.org/download/linux/ubuntu/
echo
echo "Setting up PostgreSQL repository"
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
wget --quiet -O - 'https://www.postgresql.org/media/keys/ACCC4CF8.asc' | apt-key add -
apt-get -y update
[[ $? -ne 0 ]] && echo "Error, new repository could not be added (or some other issue happened)" && exit 1

echo
echo "Installing packages from PostgreSQL repository"
apt-get -y install postgresql-12 postgresql-client-12 postgresql-doc-12 pgtop python3-psycopg2
# Required for PostgREST, the first one is probably already installed but it's better to be explicit
apt-get -y install libpq5 libpq-dev

# Start the service (in case it has not already been done)
# NOTE: we use service because it works on WSL too (and calls systemctl instead when it has to)
echo
echo "Starting PostgreSQL service"
service postgresql start
sleep 5
# If using systemctl, it uses "less" or other pager to control output interactively, and we don't want that
# Normally we would use systemctl status postgresql --no-pager but in this case "cat" works too...
service postgresql status | cat

cd /  # Avoid problems with home directory permissions when using sudo to run commands as the postgres user

echo
echo "Creating superuser '$DBUSER'"
sudo -u postgres createuser -e --superuser "$DBUSER"
[[ $? -ne 0 ]] && echo "Error, user already exists or some other issue happened. Changing password below might fail"

echo
echo "Assigning password '$DBPASS' to superuser '$DBUSER'"
sudo -u postgres psql -e -c "ALTER USER $DBUSER WITH PASSWORD '$DBPASS'"

echo
echo "Checking PostgreSQL users"
sudo -u postgres psql -c '\du' 2>/dev/null >/dev/null
[[ $? -ne 0 ]] && echo "Error, PostgreSQL not installed or not working?" && exit 1
sudo -u postgres psql -c '\du' | grep " $DBUSER "
[[ $? -ne 0 ]] && echo "Error, PostgreSQL user does not exist?" && exit 1

echo
echo "BELEROFONTECH - FINISHED POSTGRESQL INSTALL SCRIPT!"

# # Optional: use this to force output to be shown, when run remotely on Azure with "run-custom-script.sh" (making the script exit status != 0 means that it didn't finish successfully)
# echo "FINISHED. Now will end script execution with error status 101..." 1>&2
# exit 101
