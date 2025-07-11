#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Starting Guix system installation..."

# Step 1: Start the Guix build daemon targeting the new system partition
echo "Starting cow-store on /mnt..."
herd start cow-store /mnt

# Step 2: Copy and set permissions for the channel configuration
echo "Copying channels.scm to /mnt/etc/..."
cp /etc/channels.scm /mnt/etc/
chmod +w /mnt/etc/channels.scm

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
