#!/bin/bash

# Replace these with actual partition names
SYSTEM_DEV=/dev/nvme0n1p1    # ext4 root partition
EFI_DEV=/dev/nvme0n1p2       # vfat EFI partition
DATA_DEV=/dev/nvme0n1p3      # optional data partition

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

# Create base directories
mkdir -p /mnt/{gnu,var,etc,home,tmp}
chmod 0555 /mnt/gnu
chmod 0755 /mnt/var /mnt/etc /mnt/home
chmod 1777 /mnt/tmp
chown root:root /mnt/gnu /mnt/var /mnt/etc /mnt/home /mnt/tmp
