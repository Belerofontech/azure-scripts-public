#!/bin/bash
# Script to configure and auto-activate byobu (simplified tmux wrapper) at login, on a Ubuntu (18.04) system
#
# Based on the previous cloud-config.txt file (runcmd and write_files sections) from the former "vm-ubuntuserver-1804" template (...)
#
# NOTE: this script can also be used by a normal (non-root) user
# NOTE: the byobu config is applied to ONE user only!

echo
echo "BELEROFONTECH - STARTING CUSTOM 'BYOBU CONFIG AND ENVIRONMENT' INIT!"

# Optional: more debug info (show executed commands)
# set -x

sh -xc 'date ; env ; whoami ; pwd'

# Define default variable values if missing
# NOTE: in this case, only MAINUSER can be defined/used, and only if runnig as root

# In this script being root is not a requirement, but the behaviour changes a bit
if [[ $( id -u ) != 0 ]]
then
    # The current user (the one that executes the script) should be in the USER env. variable
    unset MAINUSER && [[ ! -z "$USER" ]] && [[ "root" != "$USER" ]] && MAINUSER="$USER"
    [[ -z "$MAINUSER" ]] && echo "Error, cannot automatically set the value for MAINUSER variable. Try using sudo?" && exit 1

    # Configure and auto-activate byobu at login
    byobu-enable
    byobu-enable-prompt
    byobu-ctrl-a emacs
    # Run at least a simple command inside byobu once, so that it will create all its config files
    byobu -c "ls -la ~/.byobu"
else
    # Running as root

    # MAINUSER is the preferred/expected var to get the desired value from outside; SUDO_USER can be used also,
    # in case MAINUSER is not defined. If none of the two are defined/available, set a default value: "belero"
    [[ -z "$MAINUSER" ]] && [[ ! -z "$SUDO_USER" ]] && [[ "root" != "$SUDO_USER" ]] && MAINUSER="$SUDO_USER"
    [[ -z "$MAINUSER" ]] && MAINUSER="belero"
    echo "Value for MAINUSER variable: $MAINUSER"

    # Configure and auto-activate byobu at login
    sudo -E -u $MAINUSER byobu-enable
    sudo -E -u $MAINUSER byobu-enable-prompt
    sudo -E -u $MAINUSER byobu-ctrl-a emacs
    # Run at least a simple command inside byobu once, so that it will create all its config files
    sudo -E -u $MAINUSER byobu -c "ls -la /home/$MAINUSER/.byobu"
fi

# Modify byobu key-bindings config file to use CTRL-B as prefix (tmux default)
cat > /home/$MAINUSER/.byobu/keybindings.tmux << EOF
unbind-key -n C-a
unbind-key -n C-b
set -g prefix ^B
set -g prefix2 F12
bind b send-prefix
EOF
chown $MAINUSER:$MAINUSER /home/$MAINUSER/.byobu/keybindings.tmux
chmod 0644 /home/$MAINUSER/.byobu/keybindings.tmux
# Enable again all the usual system info at each login (byobu disables it by creating this file)
rm -f /home/$MAINUSER/.hushlogin

echo
echo "BELEROFONTECH - FINISHED CUSTOM 'BYOBU CONFIG AND ENVIRONMENT' INIT!"

# # Optional: use this to force output to be shown, when run remotely on Azure with "run-custom-script.sh" (making the script exit status != 0 means that it didn't finish successfully)
# echo "FINISHED. Now will end script execution with error status 101..." 1>&2
# exit 101
