# azure-scripts-public

Templates and scripts for Azure Resource Management (for VM creation, etc.) and automated software installation and configuration for Ubuntu VMs in Azure.

For additional details, see README.md inside each subfolder

## Scripts changelog

* Version: 2.1.1.0, 2021-02-09
  * Various minor improvements:
    * install-azure-cli.sh: do the first run of az command as the main user, so that the ~/.azure dir is not created with root permissions.
    * install-postgres-12.sh: add some informative messages at the end with the expected/recommended config. steps to be taken next.

* Version: 2.1.0.0, 2021-01-21
  * First public release.
