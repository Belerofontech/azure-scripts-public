#!/bin/bash
# Script to configure and auto-activate byobu (simplified tmux wrapper) at login, on a Ubuntu (18.04) system
#
# Based on the previous cloud-config.txt file (runcmd and write_files sections) from the former "vm-ubuntuserver-1804" template (...)
#
# NOTE: the byobu config is applied to ONE user only!
# NOTE: this script no longer can be used by "normal" (non-root) users (...)

# Define default variable values if missing

# MAINUSER is the preferred/expected var to get the desired value from outside; SUDO_USER can be used also,
# in case MAINUSER is not defined. If none of the two are defined/available, set a default value: "belero"
[[ -z "$MAINUSER" ]] && [[ ! -z "$SUDO_USER" ]] && [[ "root" != "$SUDO_USER" ]] && MAINUSER="$SUDO_USER"
[[ -z "$MAINUSER" ]] && MAINUSER="belero"
echo "Value for MAINUSER variable: $MAINUSER"

# Check for root permissions (user id = 0)
if [[ $( id -u ) != 0 ]]
then
    echo "This script must be run with root privileges"
    exit 1
fi

echo
echo "BELEROFONTECH - STARTING CUSTOM 'BYOBU CONFIG AND ENVIRONMENT' INIT!"

# Leave trace of this script's output. See: https://unix.stackexchange.com/a/145654
exec &> >(tee -a /var/log/belero-install-scripts.log)
chmod -f o-rwx /var/log/belero-install-scripts.log

# Optional: more debug info (show executed commands)
# set -x

sh -xc 'date ; env ; whoami ; pwd'

# Configure and auto-activate byobu at login: add it to .profile (only if not already done)
# TO-DO: maybe do it for all users, in /etc/profile.d/... instead?
grep -q '# Belerofontech - Help before launching byobu. Can be skipped with ENTER"' /home/$MAINUSER/.profile
if [[ $? -eq 1 ]]
then
    echo | tee -a /home/$MAINUSER/.profile
    echo '# Belerofontech - Help before launching byobu. Can be skipped with ENTER' | tee -a /home/$MAINUSER/.profile
    echo 'echo ; echo "BELEROFONTECH - BYOBU. F1: help; F7: output mgmt., then / for search; F9: cfg."' | tee -a /home/$MAINUSER/.profile
    echo 'read -s -t 5 -p "  PuTTY: keyb. cfg. if needed: \"Xterm R6\"; Alt-F12: mouse mode     (ENTER: OK)" ; echo' | tee -a /home/$MAINUSER/.profile
    # Set correct permissions, just in case
    chown $MAINUSER:$MAINUSER /home/$MAINUSER/.profile
    chmod 0644 /home/$MAINUSER/.profile
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
