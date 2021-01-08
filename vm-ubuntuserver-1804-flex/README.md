# azure-scripts-public/vm-ubuntuserver-1804-flex

Azure ARM templates and scripts for creating Ubuntu Server 18.04 VMs in an automated way.

NOTE: [Azure CLI 2.0](https://docs.microsoft.com/en-us/cli/azure/?view=azure-cli-latest) and Linux (WSL works too) are required.

**NOTE: For a simplified guide for the most typical uses, see [QUICKSTART.md](QUICKSTART.md)**.

The VM initialization is done via [cloud-init](https://cloudinit.readthedocs.io) (settings and commands are defined in **cloud-config.txt** file: some packages are installed with apt-get, some settings are stored in /etc/profile.d, etc.).

**IMPORTANT NOTE**: if deploying with methods other than `deploy.sh` (for instance, from Azure Portal), the latest/custom cloud-config.txt file will NOT be used, the default values for SubscriptionId, etc. will also not be set, and virtualMachineName and other parameters may need to be defined in parameters.json (instead of being asked for interactively). To use **a custom cloud-config.txt file** in those cases (instead of the default one), set `customData` parameter in `template.json` to the base64-encoded contents of the desired file; the base64 contents can be calculated with the following command: `gzip -c cloud-config-file-to-read.txt | base64 -w0`. To use no cloud-init, set `customData` to `Iw==` (empty value in base64); the VM will be the default Azure Ubuntu 18.04 image with no further modifications.

Deploying methods for this template:

* `deploy.sh`: this is the **recommmended** and most complete/flexible script. Supports custom cloud-init initialization (from a manually defined file). See details below.

* **Alternative, manually from Azure Portal**: click [here](https://portal.azure.com/#create/Microsoft.Template) or go to "Create a resource", search for "Template deployment (deploy using custom templates)" and select it, then click "Create". Finally click on "Build your own template in the editor" and copy the template.json file contents and click "Save".

* Here, with the following button (based on [this article](https://www.noelbundick.com/posts/deploying-arm-templates-from-a-url/); valid only from a GitHub public repository):

  [![Deploy to Azure](https://azuredeploy.net/deploybutton.svg)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FBelerofontech%2Fazure-scripts-public%2Fmaster%2Fvm-ubuntuserver-1804-flex%2Ftemplate.json)

## deploy.sh usage (from Linux shell)

The following **default values** are used during the deployment unless others are specified via command-line parameters:

* resourceGroupLocation: "westeurope" (change to other if different settings which are not available yet in all regions, are needed).

* NOTE: it is recommended not to modify other settings or variables inside the script.

Script usage:

`./deploy.sh -h | --help`

`./deploy.sh [-i <subscriptionId>] [-g <resourceGroupName>] [-n <deploymentName>] [-l <resourceGroupLocation>] [-c <cloud-config-txt-filename>] [optional_extra_parameters_for_create]`

All the script parameters are optional, and the script asks for them if not present (except for subscriptionId, because the current/active one will be used; and resourceGroupLocation -- West Europe is the default value).

* resourceGroupName: Azure RM resource group where the resources will be created. The resource group will be created if it did not exist.

* deploymentName: name for the creation task (useful for logs and monitoring from Azure Portal). If the script is used several times in a row, it is advisable to use **different deployment names** for each one, for clarity.

* resourceGroupLocation: Azure region (e.g. "westeurope") used if creating a new resource group.

VM creation template parameters can be included, and will be passed to the deployment command. All the parameters used by the template (defined in **parameters.json**) can be used. They can be modified in that file, or specified directly in the command line (as "optional_extra_parameters_for_create"; see examples below). The most commonly used template parameters are:

* **tagsVector**: array/list of tags to be used for all the resources created; it must at least contain the "Customer" tag (use the customer short code; default value: "BELERO"). Default values in parameters.json are: { "Customer": "BELERO", "Project": "AA-NNN-CCCCCC" }

  * NOTE that some other tags are defined also in the template.json file for internal tracking ("TemplateName", etc.), do not modify them!

* resourceLocation: Azure region (default: "westeurope") used for the new resources. NOTE that it does not need to be the same value than for the resource group.

* **virtualMachineName** (**required**, will be asked for if not set): the new VM name. This CAN NOT be changed manually later from Azure Portal, once the resource is created.

* **adminPublicKey**: ssh authorized public key to be used for the admin user (**required, because user-password logins are disabled by default**); see [this article](https://blogs.msdn.microsoft.com/cloud_solution_architect/2016/08/24/generating-ssh-keys-for-azure-linux-vms/) for more info; a default value is provided although it is recommended to change it for production use; can be modified at any time from the \"Reset password\" blade in Azure Portal.

* virtualMachineSize: the VM size; use values from [this list](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/sizes-general); default: "Standard_B2s" (2 CPUs, 4 GB RAM).

* diskSizeGB: OS disk size, in GB (default: 32). NOTE: minimum is 30 GB; use sizes in [this list](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/about-disks-and-vhds) because size will be rounded up to one of those, for pricing; can be changed manually later from Azure Portal, when the VM is powered off, but never to decrease size.

* storageAccountType: type of disks used (default: "StandardSSD_LRS" for Standard SSD, with intermediate performance between "Standard_LRS" and "Premium_LRS"; change to "Standard_LRS" for Standard -magnetic- HDDs, or to "Premium_LRS" for Premium SSD -the initial and faster type of SSDs-). This can also be changed manually later from Azure Portal, when the VM is powered off.

* publicIpAddressType: IP address type ("Dinamic"/"Static") (default: "Dinamic").

* autoShutdownStatus: VM auto-shutdown (default: "Disabled").

* autoShutdownTime (default: "19:00"): time (UTC) for VM shutdown (everyday), if autoShutdownStatus is enabled.

* autoShutdownNotificationEmail: e-mail address to send auto-shutdown notifications to (default, that **needs to be modified**: USE_A_REAL_EMAIL_ADDRESS@belerofontech.com).

* autoShutdownNotificationWebhook: URL to send auto-shutdown notifications to (default: none).

  * NOTE: if autoShutdownStatus is set to "Enabled", at least one of the e-mail or webhook URL parameters must be set.

E.g.:

`./deploy.sh`

`./deploy.sh -c cloud-cfg.txt`

Will use the specified cloud-init config file. If it does not exist, no cloud-init specific config will be used (the VM will be the default Azure Ubuntu 18.04 image with no further modifications). If the parameter is not specified, the default "cloud-config.txt" file will be used.

`./deploy.sh -g NEWGROUP -n newvmdeploy1 virtualMachineName=vmtest-ub18`

Will not ask for the resource group name, deployment name, or VM name (so, the script will run in non-interactive mode, not asking for any information before deployment).

`./deploy.sh -i xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -g NEWGROUP -n newvmdeploy2 virtualMachineName=vmtest-ub18 -l northeurope --debug`

Will also use specific values for subscriptionId and resourceGroupLocation, and show verbose information (useful to diagnose problems) thanks to the "--debug" extra parameter.

NOTE that parameters can be passed/overriden directly in the command line (and even be provided in an external file indicated by **@file_name**; see [this article](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-deploy-cli#parameters) for more info):

`./deploy.sh -g NEWGROUP -n newvmdeploy3 virtualMachineName=vmtest-ub18 autoShutdownStatus=Enabled diskSizeGB=64 virtualMachineSize=Standard_B1s adminPublicKey=@example-public-key-file-openssh.txt`

`./deploy.sh -g NEWGROUP -n newvmdeploy4 virtualMachineName=vmtest-ub18 autoShutdownStatus=Enabled diskSizeGB=64 virtualMachineSize=Standard_B1s adminPublicKey=@example-public-key-file-openssh.txt tagsVector=@example-tags.json`

In the last example, **only** the tags in the `example-tags.json` file will be used, and the ones in parameters.json will be ignored. This is the **recommended** way to specify tags (specially if no other parameters are going to be modified).

## VM settings which are fixed

In the ARM template, the following settings are hardcoded:

* Storage type: Managed disks

  * NOTE: for very big disks which are not fully used, it could be more cost-effective to use unmanaged disks (see [this doc](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/standard-storage#pricing-and-billing)), specially for Standard HDDs. Note that in that case transaction costs apply, and that the VM needs to be modified substantially to be able to use unmanaged disks (...)
