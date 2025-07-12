#!/bin/bash

CONFIG_FILE="config.scm"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: '$CONFIG_FILE' not found."
  exit 1
fi

# Extract current values from config.scm
CURRENT_USER=$(grep -m1 '(name "' "$CONFIG_FILE" | sed -E 's/.*\(name "(.*)"\).*/\1/')
CURRENT_IP=$(grep -m1 '(value "' "$CONFIG_FILE" | sed -E 's/.*\(value "(.*)"\).*/\1/')
CURRENT_ZRAM=$(grep -m1 '(size "' "$CONFIG_FILE" | sed -E 's/.*\(size "(.*)"\).*/\1/')

# Prompt user
read -rp "Enter new username (current: $CURRENT_USER): " NEW_USER
NEW_USER=${NEW_USER:-$CURRENT_USER}

read -rp "Enter new static IP (current: $CURRENT_IP): " NEW_IP_RAW
NEW_IP_RAW=${NEW_IP_RAW:-$CURRENT_IP}

# Append /24 if not already present
if [[ "$NEW_IP_RAW" == */* ]]; then
  NEW_IP="$NEW_IP_RAW"
else
  NEW_IP="${NEW_IP_RAW}/24"
fi

read -rp "Enter new ZRAM size (current: $CURRENT_ZRAM): " NEW_ZRAM
NEW_ZRAM=${NEW_ZRAM:-$CURRENT_ZRAM}

# Backup and replace
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

sed -i \
  -e "s|(name \"[^\"]*\")|(name \"$NEW_USER\")|" \
  -e "s|(home-directory \"/home/[^\"]*\")|(home-directory \"/home/$NEW_USER\")|" \
  -e "s|(value \"[0-9./]*\")|(value \"$NEW_IP\")|" \
  -e "s|(size \"[0-9A-Za-z]*\")|(size \"$NEW_ZRAM\")|" \
  "$CONFIG_FILE"

echo "Updated '$CONFIG_FILE'. Backup saved as '${CONFIG_FILE}.bak'."
