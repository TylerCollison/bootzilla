#!/bin/bash
# Usage: updatePartitionUUID.sh targetPartitionPath
TARGET_PARTITION_PATH="$1";

# Check the filesystem on the target partition
e2fsck -f "$TARGET_PARTITION_PATH"

# Set the UUID of the target partition to a new random value
tune2fs -U random "$TARGET_PARTITION_PATH"