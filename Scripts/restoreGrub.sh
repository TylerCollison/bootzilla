#!/bin/bash
#Usage: restoreGrub ClonezillaImageName GrubPath
GRUB_ENTRY=$(more "$1.txt")

if [[ $(<"$2/grub/grub.cfg") = *"$GRUB_ENTRY"* ]]; then
  echo "Grub entry already exists. No edits needed."
else
  echo "Adding grub entry for image"
  echo "$GRUB_ENTRY" >> "$2/grub/grub.cfg"
fi
