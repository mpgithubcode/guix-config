#!/bin/bash

USERNAME=mperry
# Replace these with actual partition names
SYSTEM_DEV=/dev/nvme0n1p1    # ext4 root partition
EFI_DEV=/dev/nvme0n1p2       # vfat EFI partition
DATA_DEV=/dev/nvme0n1p3      # optional data partition

# Check devices before use
for dev in $SYSTEM_DEV $EFI_DEV $DATA_DEV; do
  if [ ! -b "$dev" ]; then
    echo "Device $dev not found!"
    exit 1
  fi
done


# Label the partitions
e2label $SYSTEM_DEV SYSTEM
fatlabel $EFI_DEV EFI
e2label $DATA_DEV DATA

# Trigger udev to update labels
udevadm trigger
udevadm settle

# Mount the filesystems
mount $SYSTEM_DEV /mnt
mkdir -p /mnt/boot/efi
mount $EFI_DEV /mnt/boot/efi
mkdir -p /mnt/persist
mount $DATA_DEV /mnt/persist

# Create base directories including the user home directory
mkdir -p /mnt/{gnu,var,etc,home,home/$USERNAME,tmp}

chmod 0555 /mnt/gnu
chmod 0755 /mnt/var /mnt/etc /mnt/home /mnt/home/$USERNAME
chmod 1777 /mnt/tmp
chown $USERNAME:$USERNAME /mnt/home/$USERNAME

# Make sure ownership is root for system dirs; you might want to set user ownership on home dir later
chown root:root /mnt/gnu /mnt/var /mnt/etc /mnt/home /mnt/tmp
