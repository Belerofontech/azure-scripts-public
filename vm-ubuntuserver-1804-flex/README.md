# azure-scripts-public/vm-ubuntuserver-1804-flex

<!-- TOC depthFrom:2 updateOnSave:false -->

- [Introduction](#introduction)
- [VM creation parameters (ARM template parameters)](#vm-creation-parameters-arm-template-parameters)
  - [VM characteristics which are not modifiable](#vm-characteristics-which-are-not-modifiable)
- [deploy.sh usage (from Linux shell)](#deploysh-usage-from-linux-shell)
  - [cloud-config.txt](#cloud-configtxt)
- [Template changelog](#template-changelog)

<!-- /TOC -->

---

## Introduction

Azure ARM templates and scripts for creating Ubuntu Server 18.04 VMs in an automated way.

NOTE: [Azure CLI 2.0](https://docs.microsoft.com/en-us/cli/azure/?view=azure-cli-latest) and Linux (WSL works too) are required for the `deploy.sh` script.

**NOTE: For a simplified guide for the most typical uses, see [QUICKSTART.md](QUICKSTART.md)**.

The VM initialization is done via [cloud-init](https://cloudinit.readthedocs.io) (custom settings and commands are defined in a `cloud-config.txt` file: some packages are installed with apt-get, some settings are stored in /etc/profile.d, etc.). NOTE that, since template version 2.0.0.0, the commands and changes are performed by independent scripts, which are in turn invoked/referenced from cloud-config.txt. See details at the **cloud-config.txt section** below.

Deploying methods for this template:

* `deploy.sh`: this is the most complete/flexible method. Supports full automation, custom cloud-init initialization (from a manually defined file), and manually specifying the subscription, resource group name, tags, or any other template parameter through command line arguments. See details below.

* Manually from Azure Portal: click [here](https://portal.azure.com/#create/Microsoft.Template) or go to "Create a resource", search for "Template deployment (deploy using custom templates)" and select it, then click "Create". Finally click on "Build your own template in the editor" and copy the `template.json` file contents and click "Save" (no other files in this repository can/will be used or are needed!). All the parameters will be shown (with some descriptive/help info), and you can manually change/add their values. Also, select the desired subscription, resource group, locations, etc.

* **From Azure Portal**, with the following button (based on [this article](https://www.noelbundick.com/posts/deploying-arm-templates-from-a-url/); valid only because this is a GitHub public repository). It is equivalent to the previous method, but quicker to start (this is the **recommmended** and simplest method):

  [![Deploy to Azure](https://azuredeploy.net/deploybutton.svg)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FBelerofontech%2Fazure-scripts-public%2Fmaster%2Fvm-ubuntuserver-1804-flex%2Ftemplate.json)

NOTE: when using Azure Portal, pay special care to the resource group location (**"westeurope" is the recommended value**). Also, **don't edit the cloudInitConfig parameter** in the parameter form because the new-line characters are not handled correctly there. If you need to use a specific cloud-init config, set the desired value inside the template.json file in the "Edit template" screen (or the "Edit parameters" screen) or use a base64-encoded config in the **customData** parameter instead.

## VM creation parameters (ARM template parameters)

**NOTE**: it is not recommended (nor needed normally) to modify the `template.json` file.

The most important template parameters are:

* **tagsVector**: array/list of tags to be used for all the resources created; it must at least contain the "Customer" tag (use the customer short code; default value: "BELERO"). Default values, which **should be modified**, are: { "Customer": "BELERO", "Project": "AA-NNN-CCCCCC" }

  * NOTE that some other tags are defined also in the template.json file for internal tracking ("TemplateName", etc.), do not modify them!

* resourceLocation: Azure region used for the new resources created. NOTE that it does not need to be the same value than for the resource group, but if the parameter value is empty (default case), the resource group location will be used.

* **virtualMachineName** (**required**, and has no default value; will be asked for if not set): the new VM name. This CAN NOT be changed manually later from Azure Portal, once the resource is created.

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

* cloudInitConfig: to use **a custom cloud-config.txt file contents** (instead of the default one provided). It must be a valid cloud-init file (for the simplest format, see the example [cloud-config.txt](cloud-config.txt) file). Default value: the same as the contents of that file (but without the comments, for clarity).

* customData (ADVANCED USE ONLY). If for some reason the **customData** parameter needs to be used directly, in the way expected by the Azure ARM VM template, set a value for it in this parameter (in `template.json`, or better in `parameters.json`, or even as an extra argument to `deploy.sh`). In that case, the **cloudInitConfig** parameter will be **ignored**. The value for **customData** should be the base64-encoded contents of the desired cloud-init file; this can be calculated with the following command: `gzip -c file-to-read.txt | base64 -w0`.

  NOTE: To use no cloud-init custom initialization, make sure no `cloud-config.txt` file is present if using `deploy.sh` (and don't specify a different one with the `-c` parameter), and set **customData** to `Iw==` (empty value in base64, starts with uppercase i). With no cloud-init data, the VM will be the default Azure Ubuntu 18.04 image with **no further modifications**.

### VM characteristics which are not modifiable

In the ARM template, the following characteristics are hardcoded and cannot be changed easily:

* Network structure: 1 virtual NIC (network card) per VM, and 1 dedicated VNet with 1 subnet. If a different network topology is needed, the template will need to be modified (because a VM cannot be switched to a different VNet after creation).

* Only 1 hard disk (OS disk) created initially, although data disks can be added later.

* Storage type: Managed disks

  * NOTE: for very big disks which are not fully used, it could be more cost-effective to use unmanaged disks (see [this doc](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/standard-storage#pricing-and-billing)), specially for Standard HDDs. Note that in that case transaction costs apply, and that the VM needs to be modified substantially to be able to use unmanaged disks (...)

## deploy.sh usage (from Linux shell)

Script usage:

`./deploy.sh -h | --help`

`./deploy.sh [-i <subscriptionId>] [-g <resourceGroupName>] [-n <deploymentName>] [-l <resourceGroupLocation>] [-c <cloud-config-txt-filename>] [optional_extra_parameters_for_create]`

All the script parameters are optional, and the script asks for most of them if not present (except for subscriptionId, because the current/active one should be used; and resourceGroupLocation and cloud-config-txt-filename because they have default values if none is specified).

* `resourceGroupName`: Azure RM resource group where the resources will be created. The resource group will be created if it did not exist.

* `deploymentName`: name for the creation task (useful for logs and auditing from Azure Portal). If the script is used several times in a row, it is very recommended to use **different deployment names** for each one, for clarity.

* `resourceGroupLocation`: Azure region (e.g. **"westeurope", which is the default value**) used if creating a new resource group.

* `cloud-config-txt-filename`: name of the cloud-init file to read. Default value: **"cloud-config.txt"**.

NOTE: it is also recommended not to modify other settings or variables inside the `deploy.sh` script (except perhaps subscriptionId, if the default value is not convenient, and we don't want to have to specify a new value via the `-i` parameter every time).

**ARM template parameters** can be added too, and will be passed to the deployment command. Any of the parameters used by the template (described in the "ARM template parameters" section, and detailed in `template.json`) can be specified directly in the command line (as `optional_extra_parameters_for_create`; see examples below). Some of them (like **virtualMachineName**) are mandatory and have no value by default; if no value is provided somewhere, including `optional_extra_parameters_for_create`, a value will be asked for interactively during the final stages of the script.

The `deploy.sh` script makes use of the following files:

* `template.json` (required): the main template file. When used from `deploy.sh`, most of the parameters inside this file are ignored (they are overriden by other files or command-line parameters)

* `parameters.json` (required): contains only the main / most commonly used template parameters, in a separate file for greater clarity.

* `cloud-config.txt` (optional, used by default): for cloud-init. The "cloud-config.txt" file (or a different file name if specified with `-c`) will be used *if present*. If the file does not exist (even if a custom name is specified), the default cloud-init data inside `parameters.json` will be used (it is the same as in the example `cloud-config.txt` file in this folder).

  In other words: the `deploy.sh` script **ignores (overrides) the cloudInitConfig and customData parameters** inside the JSON files, if and only if a valid `cloud-config.txt` file is used.
  
  An empty file is not accepted. To use no cloud-init custom initialization, set **customData** to `Iw==`, as described earlier.
  
  NOTE that the default `cloud-config.txt` file used by this template version causes false validation warnings because of the `#include` directive (...), but they can be ignored.

* other files (optional, none by default), specified manually as parameters inside `optional_extra_parameters_for_create` with the **@file_name** syntax. The contents of each file is set as the value for a parameter (see examples below).

**NOTE**: any template parameter that appears multiple times (or in multiple places, including the `template.json` and `parameters.json` files) will take the last value specified. The `template.json` file is read first (so it has the lowest precedence), then `parameters.json`, and finally the parameters specified directly in the **command line (highest precedence)**.

Usage examples:

`./deploy.sh`

`./deploy.sh -c cloud-cfg-custom.txt`

Will use the specified cloud-init config file.

`./deploy.sh -g NEWGROUP -n newvmdeploy1 virtualMachineName=vmtest-ub18`

Will not ask for the resource group name, deployment name, or VM name (so, the script will run in non-interactive mode, not asking for any information before deployment).

`./deploy.sh -i xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -g NEWGROUP -n newvmdeploy2 virtualMachineName=vmtest-ub18 -l northeurope --debug`

Will also use specific values for subscriptionId and resourceGroupLocation, and show verbose information (useful to diagnose problems) thanks to the "--debug" extra parameter.

NOTE that parameters can be passed/overriden directly in the command line (and even be provided in an external file indicated by **@file_name**; see [this article](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-template-deploy-cli#parameters) for more info):

`./deploy.sh -g NEWGROUP -n newvmdeploy3 virtualMachineName=vmtest-ub18 autoShutdownStatus=Enabled diskSizeGB=64 virtualMachineSize=Standard_B1s adminPublicKey=@example-public-key-file-openssh.txt`

Finally, a very complete and **recommended usage example**, without modifying any of the JSON files (specifying any desired parameter explicitly in the command line):

> `./deploy.sh -g NEWGROUP -n newvmdeploy4 -c cloud-config.txt virtualMachineName=vmtest-ub18 autoShutdownStatus=Disabled autoShutdownNotificationEmail=USE_A_REAL_EMAIL_ADDRESS@belerofontech.com diskSizeGB=32 virtualMachineSize=Standard_B2s resourceLocation=westeurope adminPublicKey=@example-public-key-file-openssh.txt tagsVector=@example-tags.json`

NOTE: in this example, **only** the tags in the `example-tags.json` file will be used, and the ones in `parameters.json` and `template.json` will be ignored. This is the **recommended** way to specify tags (because this parameter needs to be in JSON format, and it is harder to write it correctly in a shell command line).

### cloud-config.txt

The cloud-config.txt file is a YAML-format file that defines [**cloud-init** settings](https://cloudinit.readthedocs.io/en/latest/topics/examples.html) for the user/custom VM initialization (other Azure initialization is performed before that, and it is not configurable).

The most common format was used in 1.x versions of this template (see an example in [cloud-config-old.txt](cloud-config-old.txt)), and a simpler format (based on the `#include` directive, that references other shell scripts or cloud-init files;
see [this article](https://www.wintellect.com/arm-templates-and-cloud-init/) for more info) is used starting version 2.0.0.0.

The currently used content (**cloudInitConfig** parameter, in the `parameters.json` and `template.json` files) can also be seen in the example [cloud-config.txt](cloud-config.txt) file in this folder. The scripts called by default at VM init (in this order) are:

* `install-aa-basics.sh`: installs some desired basic packages and does an `apt-get dist-upgrade`.

* `install-ab-git-azure-scripts.sh`: downloads (gt clone) all this repository in the VM automatically, to facilitate later manual usage of any script needed.

* `install-zz-config-env-final.sh`: performs general environment setup (system info at login, env. variables, etc.), makes some useful info easily accesible, and does some final cleanup.

NOTE: Python packages (pip) are **not installed** during VM initialization anymore. Besides, any use of the `install-pip-packages.sh` script is now **discouraged** (requirements.txt-like files should be used instead, i.e. manually with `python3 -m pip install --user -r ...`). The script is included here only as a reference of the previous template versions behaviour.

## Template changelog

* Version: 2.1.0.0, 2021-01-20
  * Change in the DNS name associated to the IP address: now shorter, and does not contain the VM name (only its "random"/unique id at the end)
  * Added useful links to info/log files in the user home dir
  * Other minor improvements (...)
* Version: 2.0.0.0, 2021-01-11
  * IMPORTANT CHANGE: the template becomes public (new GitHub repository) to facilitate one-click ("Deploy to Azure" button) usage.
  * IMPORTANT CHANGES in the template structure: the cloud-init commands and customizations are now performed by several independent scripts, which are in turn invoked/referenced from cloud-config.txt (with the `#include` directive; NOTE that this directive causes false errors in the deploy.sh validation for some reason...).
  * Some more scripts added, for installing PostgreSQL, Microsoft SQL Server, Azure CLI, etc. (see parent folder). None of them are used by default at VM init.
  * A new script `install-ab-git-azure-scripts.sh` is added (called by default at VM init) for downloading (gt clone) all this repository in the VM automatically, thus facilitating later manual usage of the desired scripts.
  * The scripts called by default at VM init are: `install-aa-basics.sh`, `install-ab-git-azure-scripts.sh`, and `install-zz-config-env-final.sh` (in that order). The first and last one perform actions equivalent to previous **version 1.4.0.0** (that is, NO Python packages are installed with pip by default now).
  * The template has a new parameter, "cloudInitConfig", that allows for cloud-init config contents to be received directly in plain text format (not base64), so it is easier to debug and edit. It will be used if "customData" is empty. And "customData" is now empty by default, so only "cloudInitConfig" is used tipically.
  * When using apt-get, the env. var. DEBIAN_FRONTEND=noninteractive is defined now to prevent questions that might stop the automated install in some edge cases.
  * Added "wall" message indicating end of VM initialization, and some other small improvements to facilitate cloud-init status monitoring.

* Version: 1.4.0.0, 2020-12-30
  * PostgreSQL 12 installation made optional (PostgreSQL was introduced in previous non-production version, 1.3.0.0)
  * Package "python3-psycopg2" installation made optional (PostgreSQL)
  * IMPORTANT CHANGE: Python packages (pip) installation made optional

* Version: 1.3.0.0, 2020-12-29 (unused)
  * added PostgreSQL 12 installation from official apt repository
  * added the following packages: python3-venv python3-wheel
  * removed the following packages (almost always unused): coinor-cbc glpk-utils
  * minor changes in system tools packages installed. Added: neofetch for system info, gdb for omsagent, etc.
  * improved apt-get usage (using dist-upgrade for better dependencies management, adding autoremove)
  * change permissions (disable access for others) of /home/belero folder
  * added cloud-init environment info messages, for log purposes
  * improvements in the system info shown at each login (/etc/update-motd.d/50-belero-sysinfo, etc.)
  * IMPORTANT CHANGES in pip usage:
    * Installing of packages is now done in the recommended way (user-install)
    * pip invocation in the recommended way (with "python3 -m pip"...)
    * pip is also updated (for user-install only; and to a version <20.3, which has major changes)

* Version: 1.2.0.0, 2020-04-16
  * changes in packages installed, for DB access. Added: mdbtools python3-psycopg2
  * changes in Python packages (pip) installed, for DB access. Added: pymysql pandas_access

* Version: 1.1.0.0, 2019-11-05
  * contents of cloud-config.txt is now also embedded in template.json (customData parameter), for consistency;
  * use from Azure Portal will now produce the same results as manual use (with deploy.sh, etc.)

* Version: 1.0.6.0, 2019-10-25
  * profile settings moved to /etc/profile.d/...
  * Azure ephemeral disk back to its default path /mnt, and "our" mounts now in /media
  * new hack to print some cloud instance info at login

* Version: 1.0.5.0
  * new hack to add some debug info to the user history (access time, IP address, etc.) at login

* Other/older versions (...)
