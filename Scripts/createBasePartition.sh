#!/bin/bash
#Usage: createBasePartition.sh PathToManagedDisk PartitionSize PartedUnit

if (( "$#" != 3 ))
then
  echo "Error: the path the managed disk is required"
  exit 1
fi


UNIT="$3"
PART_SIZE=$2
nextFreeSpaceLineMiB=$(parted -s $1 unit MiB print free | tail -n 2 | head -1)
nextFreeSpaceMiBArray=($nextFreeSpaceLineMiB)
nextFreeSpaceStartMiBRoundedDown=${nextFreeSpaceMiBArray[0]%.*} #Round down
nextFreeSpaceStartMiB="$[${nextFreeSpaceStartMiBRoundedDown//"MiB"} + 1]" #Round up

nextFreeSpaceLine=$(parted -s $1 unit $UNIT print free | tail -n 2 | head -1)
nextFreeSpaceArray=($nextFreeSpaceLine)
nextFreeSpaceStart=${nextFreeSpaceArray[0]//$UNIT}
nextFreeSpaceStartRounded=${nextFreeSpaceStart%%.*}
nextFreeSpaceSize=${nextFreeSpaceArray[2]//$UNIT}
nextFreeSpaceSizeRounded=${nextFreeSpaceSize%%.*}
nextFreeSpaceID1=${nextFreeSpaceArray[3]}
nextFreeSpaceID2=${nextFreeSpaceArray[4]}

if [[ $nextFreeSpaceID1 == "Free" ]] && [[ $nextFreeSpaceID2 == "Space" ]] && (( $nextFreeSpaceSizeRounded > $PART_SIZE )); then

  # There is enough free space; ask for user confirmation  
  read -p "$PART_SIZE$UNIT of free space is available. Are you sure you want to create the partition? " -r
  echo    # Move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
  
    # User has confirmed. Proceed to create the partition in the next available space
    echo "Creating partition of size $PART_SIZE$UNIT from beginning of free space."
    if parted -a optimal $1 --script mkpart primary "${nextFreeSpaceStartMiB}MiB" "$[$nextFreeSpaceStartRounded + $PART_SIZE]$UNIT"; then
      echo "Partition created successfully"
      exit 0
    else
      echo "Error: there was an error while creating partition"
      exit 2
    fi
  else
    echo "Partition creation aborted"
    exit 4 
  fi
else
  echo "Error: insufficient free space"
  exit 3
fi
