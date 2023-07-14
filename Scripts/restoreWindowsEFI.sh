#!/bin/bash
#Usage: restoreWindowsEFI.sh WindowsPath
WINDOWS_PATH="$1"

# Copy the EFI files to the Windows mounted partition
echo "Copying Windows EFI files to $WINDOWS_PATH"
cp -r "Windows/EFI" "$WINDOWS_PATH"
echo "Finished adding Windows EFI files to $WINDOWS_PATH"