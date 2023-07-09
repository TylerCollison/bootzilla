#!/bin/bash
# Load DRBL setting and functions
DRBL_SCRIPT_PATH="${DRBL_SCRIPT_PATH:-/usr/share/drbl}"
DRBL_CONFIG_PATH="${DRBL_SCRIPT_PATH:-/etc/drbl}"

IMAGE_REPO_PATH="/home/partimag"
BOOT_PARTITION_PATH="/home/user/bootpart"
ISO_PARTITION_PATH="/home/user/isopart"

# Load Clonezilla live functions and configuration
source $DRBL_SCRIPT_PATH/sbin/drbl-conf-functions
source $DRBL_CONFIG_PATH/conf/drbl-ocs.conf
source $DRBL_SCRIPT_PATH/sbin/ocs-functions && source /etc/ocs/ocs-live.conf

# Load language files. For English, use "en_US.UTF-8". For Traditional Chinese, use "zh_TW.UTF-8"
ask_and_load_lang_set en_US.UTF-8 

# Select a disk for the boot partition
lsblk -a -o NAME,LABEL,PARTUUID,PARTLABEL,SIZE
echo "Select a disk for the boot partition: "
availableBootDiskLine=$(lsblk -lando PATH)
availableBootDiskArray=($availableBootDiskLine)
select targetBootDisk in "${availableBootDiskArray[@]}"
do
    test -n "$targetBootDisk" && break
    echo ">>> Invalid disk selection!!! Try Again"
done

# Ask if the user wants to create a new boot partition
read -p "Do you want to create a new boot partition? " -r
echo    # Move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  # User has confirmed. Create new partition on selected disk
  if bash "./createBasePartition.sh" "$targetBootDisk" "256" "MB"; then
    bootPartition=$(bash "./getLastOSPartition.sh" "$targetBootDisk")
  else
    # Failed to create new partition; restart
    echo "Error: failed to create new boot partition on selected disk"
    exec $(readlink -f "$0")
  fi
else
  # User has denied; Select an existing boot partition
  lsblk -a -o NAME,LABEL,PARTUUID,PARTLABEL,SIZE
  echo "Select the boot partition: "
  availablePartitionLine=$(lsblk -lano PATH | grep "$targetBootDisk")
  availablePartitionArray=($availablePartitionLine)
  select bootPartition in "${availablePartitionArray[@]}"
  do
      test -n "$bootPartition" && break
      echo ">>> Invalid partition selection!!! Try Again"
  done
fi

if fsck.vfat "$bootPartition"; then
  echo "The boot partition has a FAT32 filesystem"
else
  echo "The boot partition does not have a FAT32 filesystem or it may be damaged"
  # Ask if the user wants to format the boot partition
  read -p "Do you want to format the boot partition to FAT32? (Note: this will erase all data on the partition) " -r
  echo    # Move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    mkfs.vfat -F32 "$bootPartition"
    if fsck.vfat "$bootPartition"; then
      echo "Boot partition successfully formatted to FAT32"
    else
      # Failed to create filesystem
      echo "Error: failed to create a FAT32 filesystem on the boot partition"
      exec $(readlink -f "$0")
    fi
  fi
fi

# Mount the boot partition
mkdir "$BOOT_PARTITION_PATH"
mount "$bootPartition" "$BOOT_PARTITION_PATH"

# Setup the boot partition
if bash "./setupBootPartition.sh" "$targetBootDisk" "$BOOT_PARTITION_PATH"; then
  echo "The boot partition has been configured correctly"
else
  echo "Warning: The boot partition is not configured correctly; some operations may fail"
fi

# Select a disk to manage
lsblk -a -o NAME,LABEL,PARTUUID,PARTLABEL,SIZE
echo "Select a disk to manage: "
availableDiskLine=$(lsblk -lando PATH)
availableDiskArray=($availableDiskLine)
select targetDisk in "${availableDiskArray[@]}"
do
    test -n "$targetDisk" && break
    echo ">>> Invalid disk selection!!! Try Again"
done
targetDiskName=${targetDisk//"/dev/"}

# Mount the image repo
prep-ocsroot

# Select an image to restore
echo "Select an ISO to restore: "
imageISOs=$(ls $IMAGE_REPO_PATH)
imageRepoISOArray=($imageISOs)
select image in "${imageRepoISOArray[@]}"
do
    test -n "$image" && break
    echo ">>> Invalid disk selection!!! Try Again"
done

# Get size for partition
read -p "Enter the size (in GB) for the new ISO partition: " -r
echo # Move to a new line
partitionSize="$REPLY"

# Create new partition
if bash "./createBasePartition.sh" "$targetDisk" "$partitionSize" "GB"; then
  targetPartitionPath=$(bash "./getLastOSPartition.sh" "$targetDisk")
  targetPartitionName=${targetPartitionPath//"/dev/"}

  # Setup FAT32 filesystem on new partition
  mkfs.vfat -F32 "$targetPartitionPath"
  if fsck.vfat "$targetPartitionPath"; then
    # Mount the boot partition
    mkdir "$ISO_PARTITION_PATH"
    mount "$targetPartitionPath" "$ISO_PARTITION_PATH"

    # Unzip the ISO to the new partition
    7z x "$IMAGE_REPO_PATH/$image" -o"$ISO_PARTITION_PATH"

    # Add the grub entry for the new partition
    echo "Adding grub entry for new partition"
    bash "./restoreGrub.sh" "$IMAGE_REPO_PATH/$image" "$BOOT_PARTITION_PATH" "$targetPartitionPath"
  else
    echo "Error: failed to format new partition"
    exit 1;
  fi
  
else
  echo "Error: failed to create new partition"
  exit 1;
fi
