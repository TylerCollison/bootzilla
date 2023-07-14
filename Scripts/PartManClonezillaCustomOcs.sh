#!/bin/bash
# Load DRBL setting and functions
DRBL_SCRIPT_PATH="${DRBL_SCRIPT_PATH:-/usr/share/drbl}"
DRBL_CONFIG_PATH="${DRBL_SCRIPT_PATH:-/etc/drbl}"

IMAGE_REPO_PATH="/home/partimag"
TMP_IMAGE="tmp-image"
BOOT_PARTITION_PATH="/home/user/bootpart"
WINDOWS_PATH="/home/user/windows"

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
bootPartitionNumber=$(echo "${bootPartition##*[!0-9]}")
if bash "./setupBootPartition.sh" "$targetBootDisk" "$BOOT_PARTITION_PATH" "$bootPartitionNumber"; then
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
echo "Select an image to restore: "
imageRepoDirs=$(ls -d $IMAGE_REPO_PATH/*/ | xargs -n 1 basename)
imageRepoDirArray=($imageRepoDirs)
select image in "${imageRepoDirArray[@]}"
do
    test -n "$image" && break
    echo ">>> Invalid disk selection!!! Try Again"
done

# Select a partition to restore
echo "Select a partition to restore: "
imagePartitions=$(more "$IMAGE_REPO_PATH/$image/parts")
imagePartitionsArray=($imagePartitions)
select oldPartition in "${imagePartitionsArray[@]}"
do
    test -n "$oldPartition" && break
    echo ">>> Invalid partition selection!!! Try Again"
done

# Find the parted file
echo "Searching for parted file in Clonezilla image"
ptFile="None"
ptFiles=$(ls "$IMAGE_REPO_PATH/$image" | grep "\-pt.parted$")
ptFileArray=($ptFiles)
for pt in "${ptFileArray[@]}"
do
   if [[ "$oldPartition" = "${pt%-*}"* ]]; then
    ptFile="$pt"
   fi
done
if [[ "$ptFile" = "None" ]]; then
  echo "Error: Parted file not found"
  exit 1;
fi

# Extract info about the old partition
oldPartitionNumber=$(echo "${oldPartition##*[!0-9]}")
oldPartitionInfo=$(grep "^ $oldPartitionNumber" "$IMAGE_REPO_PATH/$image/$ptFile")
oldPartitionInfoArray=($oldPartitionInfo)
oldPartitionSize=${oldPartitionInfoArray[3]//"s"}
oldPartitionFileSystem=${oldPartitionInfoArray[4]}

# Create new partition (with ~2MB buffer)
if bash "./createBasePartition.sh" "$targetDisk" "$[$oldPartitionSize + 4096]" "s"; then
  targetPartitionPath=$(bash "./getLastOSPartition.sh" "$targetDisk")
  targetPartitionName=${targetPartitionPath//"/dev/"}
  targetPartitionNumber=$(echo "${targetPartitionPath##*[!0-9]}")
  
  # Stage the image for restoration (if restoring to a different partition)
  if bash "./stageImageForNewPartition.sh" "$IMAGE_REPO_PATH" "$image" "$oldPartition" "$targetPartitionName"; then
    echo "Restoring image to new partition at $targetPartitionName"
    ocs-sr -t -scr -k -c -r -j2 -p "command" restoreparts "$TMP_IMAGE" "$targetPartitionName"
  else
    echo "Error: failed to stage image for restoration"
    exit 1;
  fi

  # Set new UUID for added partition
  if [[ "$oldPartitionFileSystem" = "ext"* ]]; then
    echo "Detected EXT filesystem; generating new UUID"
    bash "./updateEXTPartitionUUID.sh" "$targetPartitionPath"
  elif [[ "$oldPartitionFileSystem" = "ntfs" ]]; then
    echo "Detected NTFS filesystem; generating new Volume Serial Number"
    bash "./updateNTFSPartitionUUID.sh" "$targetPartitionPath"
  else
    echo "Error: unsupported filesystem type: $oldPartitionFileSystem"
    echo "The partition UUID was not updated"
  fi

  # Add the grub entry for the new partition
  echo "Adding grub entry for new partition"
  bash "./restoreGrub.sh" "$IMAGE_REPO_PATH/$image" "$BOOT_PARTITION_PATH" "$targetPartitionPath"

  # Ask if the user wants to add Windows boot files
  read -p "Do you want to add Windows EFI boot files to the partition? " -r
  echo    # Move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    # Mount the Windows partition
    mkdir "$WINDOWS_PATH"
    mount "$targetPartitionPath" "$WINDOWS_PATH"

    # Restore the Windows EFI boot files
    bash "./restoreWindowsEFI.sh" "$WINDOWS_PATH"
  fi

  # Ask if the user wants to make the new partition available on Windows
  read -p "Do you want to make the new partition visible to Windows installations? " -r
  echo # Move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
      # Set the partition type to "Microsoft Basic Data" (11)
      # This allows Windows installations to access the partition
      echo "Setting partition type to 'Microsoft Basic Data'"
      sfdisk --part-type "$targetDisk" "$targetPartitionNumber" "EBD0A0A2-B9E5-4433-87C0-68B6B72699C7"
  fi
  
else
  echo "Error: failed to create new partition"
  exit 1;
fi

# Cleanup temporary files
rm -r "$IMAGE_REPO_PATH/$TMP_IMAGE"
