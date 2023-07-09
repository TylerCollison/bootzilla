#!/bin/bash
#Usage: setupBootPartition.sh BootDisk BootPartitionPath
BOOT_DISK="$1"
BOOT_PARTITION_PATH="$2"

if test -f "$BOOT_PARTITION_PATH/boot/grub/grub.cfg"; then
    echo "Found grub configuration in boot partition"
else
    echo "Grub configuration not found in boot partition"

    # Ask if the user wants to setup grub
    read -p "Do you want to setup grub in the boot partition? " -r
    echo # Move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        # User confirmed; install grub
        echo "Initializing grub in boot partition"
        grub-install --root-directory="$BOOT_PARTITION_PATH" "$BOOT_DISK"

        # Copy the default config file
        echo "Copying default grub configuration"
        cp "grub/grub.cfg" "$BOOT_PARTITION_PATH/boot/grub/"

        echo "Grub configuration complete"
    else
        # The boot partition is not configured; exit with error
        exit 1
    fi
fi