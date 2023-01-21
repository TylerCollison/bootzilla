#!/bin/bash
#Usage: getLastOSPartition.sh PathToManagedDisk

if (( "$#" != 1 ))
then
  echo "Error: the path the managed disk is required"
  exit 1
fi

UNIT="MiB"
newPartitionLine=$(parted -s $1 unit $UNIT print free | tail -n 3 | head -1)
newPartitionArray=($newPartitionLine)
newPartitionNumber=${newPartitionArray[0]}
newPartitionPath="$1$newPartitionNumber"

echo "$newPartitionPath"
