#!/bin/bash
# Script to deploy an Azure ARM template, from a Ubuntu (or similar) system with Azure CLI 2.0 installed
# Based on the default one from Azure (oct. 2018) with some minor corrections and additions

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)
set -euo pipefail
IFS=$'\n\t'

# Optional: more debug info (show executed commands)
# set -x

# NOTE: New parameters and comments added by Belerofontech
usage() { echo "Usage: $0 [-i <subscriptionId>] [-g <resourceGroupName>] [-n <deploymentName>] [-l <resourceGroupLocation>] [-c <cloud-config-txt-filename>] [optional_extra_parameters_for_create]" 1>&2; exit 1; }

# Azure subscription id: define a value if needed (or see below for more details)
declare subscriptionId=""
declare resourceGroupName=""
declare deploymentName=""
declare resourceGroupLocation="westeurope"
declare cloudConfigFileName="cloud-config.txt"

# Initialize parameters specified from command line
while getopts ":i:g:n:l:c:" arg
do
    case "${arg}" in
        i)
            subscriptionId=${OPTARG}
            ;;
        g)
            resourceGroupName=${OPTARG}
            ;;
        n)
            deploymentName=${OPTARG}
            ;;
        l)
            resourceGroupLocation=${OPTARG}
            ;;
        c)
            cloudConfigFileName=${OPTARG}
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
    echo "This script will look for an existing resource group, otherwise a new one will be created "
    echo "You can create new resource groups with the CLI using: az group create "
    echo "Enter the resource group name:"
    read resourceGroupName
    [[ "${resourceGroupName:?}" ]] # Fail (and exit because of set -e) if it is still empty or not defined
fi

if [[ -z "$deploymentName" ]]
then
    echo "Enter a name for this deployment:"
    read deploymentName
    [[ "${deploymentName:?}" ]] # Fail (and exit because of set -e) if it is still empty or not defined
fi

if [[ -z "$resourceGroupLocation" ]]
then
    echo "If creating a *new* resource group, you need to set a location "
    echo "You can lookup locations with the CLI using: az account list-locations "

    echo "Enter the resource group location:"
    read resourceGroupLocation
    [[ "${resourceGroupLocation:?}" ]] # Fail (and exit because of set -e) if it is still empty or not defined
fi

# Template file to be used
templateFilePath="template.json"

if [[ ! -f "$templateFilePath" ]]
then
    echo "$templateFilePath not found"
    exit 1
fi

# Parameter file to be used
parametersFilePath="parameters.json"

if [[ ! -f "$parametersFilePath" ]]
then
    echo "$parametersFilePath not found"
    exit 1
fi

# Do NOT immediately exit if any command has a non-zero exit status
set +e

# Perform several checks about Azure CLI

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
    echo "Resource group with name" $resourceGroupName "could not be found. Creating new resource group.."
    set -e
    (
        set -x
        az group create --name $resourceGroupName --location $resourceGroupLocation 1> /dev/null
    )
else
    echo "Using existing resource group..."
fi

# NOTE: Section added by Belerofontech, to allow for cloud init configuration via a "cloud-config.txt" file
if [[ -f "$cloudConfigFileName" ]]
then
    cldcfg=$(wc -c "$cloudConfigFileName" | awk '{print $1}')
    if [[ $cldcfg -ne 0 ]]
    then
        echo "Found non-empty cloud-init config file \"$cloudConfigFileName\"..."
        #Validate the cloud-init config file!
        cloud-init devel schema --config-file "$cloudConfigFileName" || VALID_ERROR=1
        [[ $cldcfg -gt 65535 ]] && echo "Error: file too big; max. allowed size is 65535 bytes" && exit 1
        if [[ "$VALID_ERROR" == "1" ]]
        then
            echo
            echo "WARNING: file did not validate correctly. Please check if it is really valid..."
            echo "YOU CAN CANCEL WITH CTRL-C IN THE NEXT 20 SECONDS!"
            ( sleep 20 ) || exit 1  # Exit if CTRL-C was pressed
        fi
        cldvalue=$(gzip -c "$cloudConfigFileName" | base64 -w0)
        cldparam="customData=$cldvalue"
    else
        echo "Found empty cloud-init config file \"$cloudConfigFileName\". It can not be used!"
        exit 1
    fi
fi

# NOTE: Section added by Belerofontech, to allow for extra parameters
if [[ $# -ne 0 ]]
then
    optparam="--parameters"
    echo "Extra parameters will be passed along to deployment command"
fi

# Start deployment
echo "Starting deployment..."
(
    set -x  # more debug info (show executed commands), only for this block (run in a sub-shell)
    az group deployment create --verbose --name "$deploymentName" --resource-group "$resourceGroupName" --template-file "$templateFilePath" --parameters "@${parametersFilePath}" ${optparam:-} ${cldparam:-} "$@"
)
if [[ $? == 0 ]]
then
    echo "Template has been successfully deployed. Available VMs in the resource group:"
    # NOTE: Added by Belerofontech, to get info about the newly created VM
    az vm list --show-details --resource-group "$resourceGroupName" --output table
fi
