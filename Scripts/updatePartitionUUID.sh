#!/bin/bash
# Usage: updatePartitionUUID.sh targetPartitionPath
TARGET_PARTITION_PATH = "$1";

# Silently set the UUID of the target partition to a new random value
tune2fs -U random "$TARGET_PARTITION_PATH" > /dev/null

# Output the new UUID
blkid "$TARGET_PARTITION_PATH" | awk -F" " '{print $2}' | cut -d '"' -f2