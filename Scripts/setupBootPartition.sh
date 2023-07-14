#!/bin/bash
#Usage: setupBootPartition.sh BootDisk BootPartitionPath BootPartitionNumber
BOOT_DISK="$1"
BOOT_PARTITION_PATH="$2"
BOOT_PARTITION_NUMBER="$3"

# Ask if the user wants to make the boot partition available on Windows
read -p "Do you want to make the boot partition visible to Windows installations? " -r
echo # Move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    # Set the partition type to "Microsoft Basic Data" (11)
    # This allows Windows installations to access the boot partition
    # This is especially useful for editing the boot partition configuration
    echo "Setting partition type to 'Microsoft Basic Data'"
    sfdisk --part-type "$BOOT_DISK" "$BOOT_PARTITION_NUMBER" "EBD0A0A2-B9E5-4433-87C0-68B6B72699C7"
fi

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