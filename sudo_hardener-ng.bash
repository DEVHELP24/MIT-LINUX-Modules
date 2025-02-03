#!/bin/bash

# Script: sudo-hardening-pro_tweaks
# Author: [NAZY-OS]
# Description: [Applies or reverts PAM and sudoers configuration changes for security hardening.]

# Flag file to indicate if changes have been applied
FLAG_FILE="/tmp/sudo-hardening-applied.flag"

# Function to display help
show_help() {
    echo "Usage: $0 {apply|revert|--help}"
    echo
    echo "Commands:"
    echo "  apply   Apply the security hardening changes."
    echo "  revert  Revert the security hardening changes."
    echo "  --help  Display this help message."
}

# Function to create backups
create_backups() {
    sudo cp /etc/pam.d/su /etc/pam.d/su.bak
    sudo cp /etc/pam.d/sudo /etc/pam.d/sudo.bak
    sudo cp /etc/sudoers /etc/sudoers.bak
    sudo cp /etc/sudoers.d/g_wheel /etc/sudoers.d/g_wheel.bak 2> /dev/null
}

# Function to check and add a line to a file if it doesn't exist
add_line_if_missing() {
    local file="$1"
    local line="$2"
    if ! grep -q "$line" "$file"; then
        echo "Adding line to $file: $line"
        echo "$line" | sudo tee -a "$file" > /dev/null
    else
        echo "Line already present in $file: $line"
    fi
}

# Function to apply changes
apply_changes() {
    # Check if changes have already been applied
    if [ -f "$FLAG_FILE" ]; then
        echo "Changes have already been applied. Please revert before applying again."
        exit 1
    fi

    # Backup existing files
    create_backups

    # Modify PAM for su and sudo
    for file in /etc/pam.d/su /etc/pam.d/sudo; do
        {
            echo "auth required pam_faillock.so preauth silent deny=8 unlock_time=1500"  # 1500 seconds = 25 minutes
            echo "auth required pam_faillock.so authfail deny=8 unlock_time=1500"
            echo "account required pam_faillock.so"
        } | sudo tee -a "$file" > /dev/null

        # Update pam_wheel config
        add_line_if_missing "$file" "auth required pam_wheel.so trust use_uid"
    done

    # Ensure the sudoers file for the wheel group exists
    add_line_if_missing "/etc/sudoers.d/g_wheel" "%wheel  ALL=(ALL) ALL"

    # Add pwfeedback to the sudoers file if not present
    add_line_if_missing "/etc/sudoers" "Defaults env_reset,pwfeedback,timestamp_timeout=10,passwd_timeout=0,insults"

    # Create a flag file to indicate changes have been applied
    touch "$FLAG_FILE"

    echo "Changes have been applied. Backup files have been created."
}

# Function to revert changes
revert_changes() {
    # Check if changes have been applied
    if [ ! -f "$FLAG_FILE" ]; then
        echo "No changes have been applied. Nothing to revert."
        exit 1
    fi

    # Restore backups
    sudo cp /etc/pam.d/su.bak /etc/pam.d/su
    sudo cp /etc/pam.d/sudo.bak /etc/pam.d/sudo
    sudo cp /etc/sudoers.bak /etc/sudoers
    sudo cp /etc/sudoers.d/g_wheel.bak /etc/sudoers.d/g_wheel 2> /dev/null

    # Remove the flag file
    rm -f "$FLAG_FILE"

    echo "Changes have been reverted."
}

# Main script logic
case "$1" in
    apply)
        apply_changes
        ;;
    revert)
        revert_changes
        ;;
    --help)
        show_help
        ;;
    *)
        echo "Invalid option: $1"
        show_help
        exit 1
        ;;
esac
