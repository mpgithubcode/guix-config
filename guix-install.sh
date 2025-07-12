#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

FLAG_FILE="/mnt/etc/.config-edited"
FORCE_EDIT=false

# Handle arguments
if [[ "$1" == "-e" ]]; then
  FORCE_EDIT=true
fi

echo "Starting Guix system installation..."
echo "Checking installer config at /mnt/etc/config.scm"

if [[ "$FORCE_EDIT" == true || ! -f "$FLAG_FILE" ]]; then
  echo "Running edit-config.sh..."
  bash edit-config.sh
  touch "$FLAG_FILE"
  echo "edit-config.sh has been run. Marker created at $FLAG_FILE."
else
  echo "edit-config.sh has already been run. Skipping (use -e to force)."
fi

# Path to the config file
CONFIG_FILE="/mnt/etc/config.scm"
BACKUP_FILE="/mnt/etc/config.scm.bak"

# Check if the file exists
if [ -f "$CONFIG_FILE" ]; then
  echo "Found $CONFIG_FILE. Backing it up..."
  cp "$CONFIG_FILE" "$BACKUP_FILE"
  echo "Backup created at $BACKUP_FILE."
else
  echo "No $CONFIG_FILE found. Skipping backup."
fi

# Step 1: Start the Guix build daemon targeting the new system partition
echo "Starting cow-store on /mnt..."
herd start cow-store /mnt

# Step 2: Copy and set permissions for the channel configuration
echo "Copying channels.scm to /mnt/etc/..."
cp ./channels.scm /mnt/etc/
cp ./config.scm /mnt/etc/
chmod +w /mnt/etc/channels.scm
chmod +w /mnt/etc/config.scm

# Step 3: Run the Guix system init using the specified channel configuration
echo "Running guix system init..."
guix time-machine -C /mnt/etc/channels.scm -- system init /mnt/etc/config.scm /mnt

# Step 4: Countdown before reboot
echo "Installation complete. Rebooting in 10 seconds..."
for i in {10..1}; do
  echo "$i..."
  sleep 1
done

reboot
