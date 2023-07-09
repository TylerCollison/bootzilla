#!/bin/bash
#Usage: getLastOSPartition.sh PathToManagedDisk

if (( "$#" != 1 ))
then
  echo "Error: the path the managed disk is required"
  exit 1
fi

pathToManagedDisk="$1"

lsblk -lano PATH | grep "$pathToManagedDisk" | sort | tail -n 1
