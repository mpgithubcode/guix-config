#!/bin/bash

# Exit on any error
set -e

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAG_FILE="$SCRIPT_DIR/.config-edited"


# Flags
FORCE_EDIT=false
FORCE_PARTITION=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -e) FORCE_EDIT=true ;;
    -p) FORCE_PARTITION=true ;;
    *) echo "Unknown option: $1" && exit 1 ;;
  esac
  shift
done

echo "Starting Guix system installation..."
echo "Checking installer config at /mnt/etc/config.scm"

# Run edit-config.sh only once unless forced
if [[ "$FORCE_EDIT" == true || ! -f "$FLAG_FILE" ]]; then
  echo "Running edit-config.sh..."
  bash edit-config.sh
  touch "$FLAG_FILE"
  echo "edit-config.sh has been run. Marker created at $FLAG_FILE."
else
  echo "edit-config.sh has already been run. Skipping (use -e to force)."
fi

# Function to check if any device has both EFI and SYSTEM labels
has_efi_and_system() {
  for disk in /dev/sd?; do
    # Check if any partitions are labeled EFI and SYSTEM
    EFI_FOUND=$(lsblk -no LABEL "$disk" | grep -Fx "EFI" || true)
    SYSTEM_FOUND=$(lsblk -no LABEL "$disk" | grep -Fx "SYSTEM" || true)
    if [[ -n "$EFI_FOUND" && -n "$SYSTEM_FOUND" ]]; then
      return 0  # Found both
    fi
  done
  return 1  # Not found
}

# Run partition script only if not already partitioned
if [[ "$FORCE_PARTITION" == true ]]; then
  echo "Forcing partition-drive.sh with -p flag..."
  bash partition-drive.sh
elif has_efi_and_system; then
  echo "EFI and SYSTEM partitions already exist. Skipping partition-drive.sh."
else
  echo "No disk found with both EFI and SYSTEM labels. Running partition-drive.sh..."
  bash partition-drive.sh
fi

# Try to unmount first if mounted
umount /mnt/boot/efi 2>/dev/null || true
umount /mnt 2>/dev/null || true

# Ensure mount points exist
mkdir -p /mnt

# Mount SYSTEM partition at /mnt
mount LABEL=SYSTEM /mnt

mkdir -p /mnt/etc
mkdir -p /mnt/boot/efi

# Mount EFI partition at /mnt/boot/efi
mount -t vfat -o umask=0077 LABEL=EFI /mnt/boot/efi

echo "Partitions mounted:"
mount | grep '/mnt'

# Path to the config file
CONFIG_FILE="/mnt/etc/config.scm"
BACKUP_FILE="/mnt/etc/config.scm.bak"

# Check if the config file exists and back it up
if [ -f "$CONFIG_FILE" ]; then
  echo "Found $CONFIG_FILE. Backing it up..."
  cp "$CONFIG_FILE" "$BACKUP_FILE"
  echo "Backup created at $BACKUP_FILE."
else
  echo "No $CONFIG_FILE found. Skipping backup."
fi

# Start the build daemon
echo "Starting cow-store on /mnt..."
herd start cow-store /mnt

# Copy channel configuration
echo "Copying channels.scm and config.scm to /mnt/etc/..."
cp ./channels.scm /mnt/etc/
cp ./config.scm /mnt/etc/
chmod +w /mnt/etc/channels.scm /mnt/etc/config.scm

# Initialize the Guix system
echo "Running guix system init..."
guix time-machine -C /mnt/etc/channels.scm -- system init /mnt/etc/config.scm /mnt

# Countdown to reboot
echo "Installation complete. Rebooting in 10 seconds..."
for i in {10..1}; do
  echo "$i..."
  sleep 1
done

reboot
