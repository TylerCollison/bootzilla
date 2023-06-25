#!/bin/bash
#Usage: restoreGrub.sh ClonezillaImageName BootPartitionPath UUID
GRUB_ENTRY=$(more "$1.txt")
UUID="$3"

# Replace the UUID placeholder with the new value
GRUB_ENTRY=$(sed "s/<UUID>/$UUID/g")

if [[ $(<"$2/grub/grub.cfg") = *"$GRUB_ENTRY"* ]]; then
  echo "Grub entry already exists. No edits needed."
else
  echo "Adding grub entry for image"
  echo "$GRUB_ENTRY" >> "$2/grub/grub.cfg"
fi
