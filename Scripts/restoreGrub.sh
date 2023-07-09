#!/bin/bash
#Usage: restoreGrub.sh ClonezillaImagePath BootPartitionPath RestorePartitionPath
CLONEZILLA_IMAGE_PATH="$1"
BOOT_PARTITION_PATH="$2"
TARGET_PARTITION_PATH="$3"

# Get the UUID for the partition
echo "Getting UUID of $TARGET_PARTITION_PATH"
UUID=$(blkid -p "$TARGET_PARTITION_PATH" | grep -o -P '(?<= UUID=").*?(?=")')

# Get the name for the grub entry
read -p "Enter a name for the OS boot entry: " -r
echo # Move to a new line
GRUB_ENTRY_NAME="$REPLY"

# Replace the UUID placeholder with the new value
echo "Setting UUID $UUID in the grub entry for the image"

# Replace the NAME placeholder with the new value
echo "Setting $GRUB_ENTRY_NAME as the name in the grub entry for the image"

# Determine whether a custom grub entry has been defined for the image
if test -f "$CLONEZILLA_IMAGE_PATH.cfg"; then
  # A custom grub configuration exists for the image; use it
  echo "Found custom grub configuration for image"
  GRUB_ENTRY=$(more "$CLONEZILLA_IMAGE_PATH.cfg" | sed "s/<UUID>/$UUID/g" | sed "s/<NAME>/$GRUB_ENTRY_NAME/g")
else
  # Use a default grub configuration
  echo "No custom grub configuration detected"

  # Ask the user to select a default entry template
  echo "Select a default grub entry for the image: "
  entriesLine=$(ls grub/DefaultEntries)
  entriesArray=($entriesLine)
  select entry in "${entriesArray[@]}"
  do
      test -n "$entry" && break
      echo ">>> Invalid selection!!! Try Again"
  done
  GRUB_ENTRY=$(more "grub/DefaultEntries/$entry" | sed "s/<UUID>/$UUID/g" | sed "s/<NAME>/$GRUB_ENTRY_NAME/g")
fi

echo "Adding partition entry to grub config at $BOOT_PARTITION_PATH/boot/grub/grub.cfg"
if [[ $(<"$BOOT_PARTITION_PATH/boot/grub/grub.cfg") = *"$GRUB_ENTRY"* ]]; then
  echo "Grub entry already exists. No edits needed."
else
  echo "Adding grub entry for image"
  echo "$GRUB_ENTRY" >> "$BOOT_PARTITION_PATH/boot/grub/grub.cfg"
fi
