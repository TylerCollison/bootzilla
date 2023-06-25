#!/bin/bash
# Usage: stageImageForNewPartition.sh ImageRepo OriginalImage OldPartition NewPartition

IMAGE_REPO="$1"
ORIGINAL_IMAGE="$2"
OLD_PARTITION="$3"
NEW_PARTITION="$4"

TEMP_IMAGE="tmp-image"
PARTITION_MANIFEST="parts"

# Create a temporary image for the new partition
mkdir "$IMAGE_REPO/$TEMP_IMAGE"

# Get all files from the original image
imageFiles=$(ls "$IMAGE_REPO/$ORIGINAL_IMAGE/" | xargs -n 1 basename)
imageFilesArray=($imageFiles)

# Link all files in the temporary image directory
for file in "${imageFilesArray[@]}"
do
  if [[ "$file" == "$OLD_PARTITION"* ]]; then
    # The file references the old partition; link it with the name of the new partition
    newFileName="${file/"$OLD_PARTITION"/"$NEW_PARTITION"}"
    ln -s "$IMAGE_REPO/$ORIGINAL_IMAGE/$file" "$IMAGE_REPO/$TEMP_IMAGE/$newFileName"
  elif [[ "$file" == "$PARTITION_MANIFEST" ]]; then
    # Copy and edit the partition manifest, replacing the old partition with the new one
    cp "$IMAGE_REPO/$ORIGINAL_IMAGE/$file" "$IMAGE_REPO/$TEMP_IMAGE/$file"
    sed -i "s/"$OLD_PARTITION"/"$NEW_PARTITION"/g" "$IMAGE_REPO/$TEMP_IMAGE/$PARTITION_MANIFEST"
  else
    # The file does not reference the old partition; link it without modification
    ln -s "$IMAGE_REPO/$ORIGINAL_IMAGE/$file" "$IMAGE_REPO/$TEMP_IMAGE/$file"
  fi
done
