# azure-scripts-public/vm-ubuntuserver-1804-flex (quick start guide)

Azure ARM templates and scripts for creating Ubuntu Server 18.04 VMs.

NOTE: [Azure CLI 2.0](https://docs.microsoft.com/en-us/cli/azure/?view=azure-cli-latest) and Linux are required.

The VM initialization is done via [cloud-init](https://cloudinit.readthedocs.io) (settings and commands are defined in **cloud-config.txt** file...). For more details, see [README.md](README.md).

For other deploying methods, including manually from Azure Portal: see [README.md](README.md).

## deploy.sh usage (from Linux shell)

Script usage:

`./deploy.sh -h | --help`

`./deploy.sh [-i <subscriptionId>] [-g <resourceGroupName>] [-n <deploymentName>] [-l <resourceGroupLocation>] [optional_extra_parameters_for_create]`

Parameters meaning:

* resourceGroupName: Azure RM resource group where the VM will be created. The groug will be created if it did not exist.

* deploymentName: name for the creation task (useful for logs and monitoring from Azure Portal). If the script is used several times in a row, it is advisable to use **different deployment names** for each one, for clarity.

* resourceGroupLocation: Azure region (e.g. "westeurope") used if creating a new resource group.

All the script parameters are optional, and the script asks for them if not present (except for subscriptionId, because the current/active one will be used; and resourceGroupLocation -- "westeurope" is the default value).

Needed steps:

1. Review the parameters used by the template (defined in **parameters.json**), if needed (VM size, etc.). Most of them can be modified afterwards in an easier way, from Azure Portal, once the VM is created (and powered off). It is important to check, specifically:

    * resourceLocation: Azure region (default: "westeurope") used for the new resources. NOTE that it does not need to be the same value than for the resource group.

    It the default value is not OK, it can be modified in the command line (recommended way, see examples below). So, normally we don't need to modify the parameters.json file...

2. Review the provided `cloud-config.txt` file, or delete/rename it (in that case, the VM will be the default Azure Ubuntu 18.04 image with no further modifications). If the parameter is not specified, the default "cloud-config.txt" file will be used.

3. Edit the `example-tags.json` file, and specify at least the correct customer, project and environment (for example, "Testing") details for the resource tags.

4. Optional: if the default ssh authorized public key is not wanted (it can be modified later, from Azure Portal; for more details, see [README.md](README.md)), modify the `example-public-key-file-openssh.txt` file to use a different one.

5. Proceed with the deploy. From a Linux shell in this folder (`vm-ubuntuserver-1804-flex`), run:

    `./deploy.sh -g NEWGROUP -n 20201223_testdeploy virtualMachineName=vmtest-ub18 adminPublicKey=@example-public-key-file-openssh.txt tagsVector=@example-tags.json`

6. Optional: if needed, add more parameters to modify the resources location (both for the resource group, and the resources that will be created). For example:

    `./deploy.sh -i xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -g NEWGROUP -n 20201223_testdeploy -l northeurope resourceLocation=northeurope virtualMachineName=vmtest-ub18 adminPublicKey=@example-public-key-file-openssh.txt tagsVector=@example-tags.json`

7. Optional: **in case of problems**, add `--debug` at the **end** of the command (after any other parameters) so that more verbose info is printed.
