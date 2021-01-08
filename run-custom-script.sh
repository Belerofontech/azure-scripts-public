#!/bin/bash
# Script to (send and) run a local script in an Azure VM, remotely from a Ubuntu system
# Makes use of this Azure extension: https://github.com/Azure/custom-script-extension-linux
# The script is always run without parameters (the extension does not support adding them)
# See additional info in https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-linux
#
# Requires/uses Azure CLI 2.0
#
# IMPORTANT: the script is sent and stored in the VM (root access only, but in clear text), so DO NOT PUT PASSWORDS,
# tokens, or any other SENSITIVE INFORMATION inside it!
# Execution results are stored also in the VM, in a folder per execution, under /var/lib/waagent/custom-script/download/

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)
set -euo pipefail
IFS=$'\n\t'

# Optional: more debug info (show executed commands)
# set -x

usage() { echo "Usage: $0 -i <subscriptionId> -g <resourceGroupName> -n <vmName> -s <scriptName>" 1>&2; exit 1; }

# Azure subscription id: define a value if needed (or see below for more details)
declare subscriptionId=""
declare resourceGroupName=""
declare vmName=""
declare scriptFilePath=""

# Initialize parameters specified from command line
while getopts ":i:g:n:s:" arg
do
    case "${arg}" in
        i)
            subscriptionId=${OPTARG}
            ;;
        g)
            resourceGroupName=${OPTARG}
            ;;
        n)
            vmName=${OPTARG}
            ;;
        s)
            scriptFilePath=${OPTARG}
            ;;
        *)
            echo "Invalid option(s)"
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# Prompt for parameters is some required parameters are missing

# Optional: ask for the subscriptionId (for instance, in case there are several subscriptions available)
# if [[ -z "$subscriptionId" ]]
# then
#     echo "Your subscription ID can be looked up with the CLI using: az account show"
#     echo "Enter your subscription ID:"
#     read subscriptionId
#     [[ "${subscriptionId:?}" ]] # Fail (and exit because of set -e) if it is still empty or not defined
# fi

if [[ -z "$resourceGroupName" ]]
then
    echo "Enter the VM resource group name:"
    read resourceGroupName
    [[ "${resourceGroupName:?}" ]] # Fail (and exit because of set -e) if it is still empty or not defined
fi

if [[ -z "$vmName" ]]
then
    echo "Enter the VM name:"
    read vmName
    [[ "${vmName:?}" ]] # Fail (and exit because of set -e) if it is still empty or not defined
fi

if [[ -z "$scriptFilePath" ]]
then
    echo "Enter the script location (file path):"
    read scriptFilePath
    [[ "${scriptFilePath:?}" ]] # Fail (and exit because of set -e) if it is still empty or not defined
fi

### Perform several checks on the script

# Is it a normal file?
if [[ ! -f "$scriptFilePath" ]]
then
    echo "$scriptFilePath file not found"
    exit 1
fi

# Do NOT immediately exit if any command has a non-zero exit status
set +e

# Does it have the correct format, encoding, etc.?
file -b "$scriptFilePath" | grep -q -e "CRLF" -e "BOM" -e "UTF-16" -e "UTF-32"
if [[ $? = 0 ]]
then
    # NOTE: in this case, unix line-endings is not actually required (the extension seems to fix it) but it is advisable anyway...
    echo "Script must be have UTF-8 encoding, unix line-endings format (no CRLF), and no BOM mark (see https://en.wikipedia.org/wiki/Byte_order_mark)"
    echo "Current script is:"
    file -b "$scriptFilePath"
    echo "You can probably use dos2unix to (maybe partially) fix it..."
    exit 1
fi

# Does it start with a #!/bin/bash line?
# TO-DO: allow also #!/bin/sh ?
head -n1 "$scriptFilePath" | grep -q "^#!/bin/bash$"
if [[ $? != 0 ]]
then
    echo "Script must start with a 'shebang' line: #!/bin/bash$"
    exit 1
fi

### Perform several checks about Azure CLI

az account show 1> /dev/null
if [[ $? != 0 ]]
then
    echo "Executing az login..."
    # Login to azure using your credentials
    az login --output table || exit 1
fi

# Set the default subscription id, if it was provided
if [[ ! -z "$subscriptionId" ]]
then
    az account set --subscription $subscriptionId
else
    echo "The following subscriptions are available. The one listed with IsDefault=true will be used"
    echo "NOTE: execute 'az account set --subscription xxx' if you need to change the default one"
    az account list --output table || exit 1
    echo
    echo "PLEASE CHECK THAT THIS IS CORRECT. YOU CAN CANCEL WITH CTRL-C IN THE NEXT 20 SECONDS!"
    ( sleep 20 ) || exit 1  # Exit if CTRL-C was pressed
fi

# Check for existing RG
# NOTE: modified by Belerofontech, because the original check wit "az group show" did not always work
##az group show --name $resourceGroupName 1> /dev/null
echo
az group list --output json | grep -i "\"name\": \"$resourceGroupName\"," 1> /dev/null
if [[ $? != 0 ]]
then
    echo "Resource group with name" $resourceGroupName "could not be found"
    exit 1
fi

### Launch the script remotely

# -e: immediately exit if any command has a non-zero exit status
set -e

# Parameter file preparation
file_name=$(basename "$scriptFilePath")
tmp_file=$(tempfile)
tmp_file_name="$file_name".tmp$(basename "$tmp_file")
script_content=$(gzip -c "$scriptFilePath" | base64 -w0)
# Timestamp must have a unique value every time we run the script (if we want to run it several times), so we use the current time
timestamp_now=$(date +%s)
# Create the temporary parameters file, which contains the script (base64 encoded) and the timestamp. These will be the parameters passed to the CustomScript extension
echo '{' > "$tmp_file_name"
echo '  "script": "'$script_content'",' >> "$tmp_file_name"
echo '  "timestamp": '$timestamp_now >> "$tmp_file_name"
echo '}' >> "$tmp_file_name"

# Start execution
echo "Starting script execution..."
echo "Script output (inside the VM) will be placed in /var/lib/waagent/custom-script/download/..."
echo "If the script fails (return value != 0), the script output will also be displayed below..."

# Do NOT immediately exit if any command has a non-zero exit status
set +e

(
    set -x  # more debug info (show executed commands), only for this block (run in a sub-shell)
    az vm extension set --verbose --resource-group "$resourceGroupName" --vm-name "$vmName" --name CustomScript --publisher Microsoft.Azure.Extensions --version 2.0 --settings "$tmp_file_name"
)
if [[ $? = 0 ]]
then
    echo "Script has been successfully executed"
    echo "Execution results are stored in the VM, in a folder per execution, under /var/lib/waagent/custom-script/download/"
fi

rm -f "$tmp_file_name"
