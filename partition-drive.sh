#!/bin/bash

set -euo pipefail

# Check for root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

echo "Available drives:"
echo "------------------"

# List block devices excluding loop and partitions
lsblk -d -o NAME,SIZE,MODEL,VENDOR,TYPE | grep -w "disk"

# Ask user to select a device
read -rp "Enter the drive to partition (e.g., sda): " DRIVE

DRIVE_PATH="/dev/$DRIVE"

# Confirm
read -rp "Are you sure you want to erase and partition $DRIVE_PATH? (yes/[no]) " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Aborted."
  exit 1
fi

echo "Wiping $DRIVE_PATH..."
wipefs -a "$DRIVE_PATH"
sgdisk --zap-all "$DRIVE_PATH"

# Create partitions
# Partition 1: 1G EFI
# Partition 2: Rest of disk

echo "Creating partitions..."
parted -s "$DRIVE_PATH" mklabel gpt
parted -s "$DRIVE_PATH" mkpart primary fat32 1MiB 1GiB
parted -s "$DRIVE_PATH" set 1 esp on
parted -s "$DRIVE_PATH" mkpart primary ext4 1GiB 100%

# Wait for kernel to recognize new partitions
sleep 2

if [[ "$DRIVE_PATH" == *nvme* ]]; then
  EFI_PART="${DRIVE_PATH}p1"
  SYS_PART="${DRIVE_PATH}p2"
else
  EFI_PART="${DRIVE_PATH}1"
  SYS_PART="${DRIVE_PATH}2"
fi


# Format partitions
echo "Formatting EFI partition ($EFI_PART) as FAT32..."
mkfs.fat -F32 -n EFI "$EFI_PART"

echo "Formatting SYSTEM partition ($SYS_PART) as EXT4..."
mkfs.ext4 -L SYSTEM "$SYS_PART"

echo "Done. Partitioned $DRIVE_PATH as:"
lsblk "$DRIVE_PATH"

