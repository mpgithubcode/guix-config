#!/bin/bash

CONFIG_FILE="config.scm"

# Safety check
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: '$CONFIG_FILE' not found in the current directory."
  exit 1
fi

# Prompt for new values
read -rp "Enter new username (current: alice): " NEW_USER
read -rp "Enter new static IP (e.g., 192.168.1.100): " NEW_IP_RAW
read -rp "Enter new ZRAM size (e.g., 2G, current: 1G): " NEW_ZRAM

# Apply changes using sed (with backup)
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

# Append /24 if not present
if [[ "$NEW_IP_RAW" == */* ]]; then
  NEW_IP="$NEW_IP_RAW"
else
  NEW_IP="${NEW_IP_RAW}/24"
fi

sed -i \
  -e "s/(name \"[^\"]*\")/(name \"$NEW_USER\")/" \
  -e "s/(home-directory \"\/home\/[^\"]*\")/(home-directory \"\/home\/$NEW_USER\")/" \
  -e "s|(value \"[0-9./]*\")|(value \"$NEW_IP\")|" \
  -e "s/(size \"[0-9A-Za-z]*\")/(size \"$NEW_ZRAM\")/" \
  "$CONFIG_FILE"

echo "Updated '$CONFIG_FILE'. A backup was saved as '${CONFIG_FILE}.bak'."
