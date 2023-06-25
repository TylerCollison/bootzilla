#!/bin/bash
# Load DRBL setting and functions
DRBL_SCRIPT_PATH="${DRBL_SCRIPT_PATH:-/usr/share/drbl}"
DRBL_CONFIG_PATH="${DRBL_SCRIPT_PATH:-/etc/drbl}"

IMAGE_REPO_PATH="/home/partimag"
TMP_IMAGE="tmp-image"

# Load Clonezilla live functions and configuration
source $DRBL_SCRIPT_PATH/sbin/drbl-conf-functions
source $DRBL_CONFIG_PATH/conf/drbl-ocs.conf
source $DRBL_SCRIPT_PATH/sbin/ocs-functions && source /etc/ocs/ocs-live.conf

# Load language files. For English, use "en_US.UTF-8". For Traditional Chinese, use "zh_TW.UTF-8"
ask_and_load_lang_set en_US.UTF-8 

# Select the boot partition
echo "Select the boot partition: "
availablePartitionLine=$(lsblk -lando PATH)
availablePartitionArray=($availablePartitionLine)
select bootPartition in "${availablePartitionArray[@]}"
do
    test -n "$bootPartition" && break
    echo ">>> Invalid partition selection!!! Try Again"
done
mkdir boot
mount "$bootPartition" ./bootpart

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

# Get info about the old partition
oldPartitionNumber="${oldPartition: -1}"
oldPartitionInfo=$(grep "^ $oldPartitionNumber" "$IMAGE_REPO_PATH/$image/$targetDiskName-pt.parted")
oldPartitionInfoArray=($oldPartitionInfo)
oldPartitionSize=${oldPartitionInfoArray[3]//"s"}

# Create new partition
if bash "./createBasePartition.sh" "$targetDisk" "$oldPartitionSize" "s"; then
  targetPartitionPath=$(bash "./getLastOSPartition.sh" "$targetDisk")
  targetPartitionName=${targetPartitionPath//"/dev/"}
  
  # Stage the image for restoration (if restoring to a different partition)
  if bash "./stageImageForNewPartition.sh" "$IMAGE_REPO_PATH" "$image" "$oldPartition" "$targetPartitionName"; then
    echo "Restoring image to new partition at $targetPartitionName"
    ocs-sr -t -scr -k -c -r -j2 -p "choose" restoreparts "$TMP_IMAGE" "$targetPartitionName"
  else
    echo "Error: failed to stage image for restoration"
  fi
  
else
  echo "Error: failed to create new partition"
fi

# Set new UUID for added partition
newUUID=$(bash "./updatePartitionUUID.sh" "$targetPartitionPath")

# Add the grub entry for the new partition
bash "./restoreGrub.sh" "$image" "./bootpart" "$newUUID"

# Unmount the boot partition
unmount ./bootpart
# Cleanup temporary files
# rm -r "$IMAGE_REPO_PATH/$TMP_IMAGE"
