#!/bin/bash
# Usage: updatePartitionUUID.sh targetPartitionPath
TARGET_PARTITION_PATH="$1";

# Set the UUID (Volume Serial Number) of the target partition to a new random value
dd if=/dev/urandom bs=80 count=1 | xxd -l 80 -c 8 | tail -1 | xxd -r - "$TARGET_PARTITION_PATH"