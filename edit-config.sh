#!/bin/bash

CONFIG_FILE="config.scm"

# Source shared SCM utilities
source ./scm-utils.sh

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: '$CONFIG_FILE' not found."
  exit 1
fi

# Field label | Scheme field name | Optional transform template (e.g., */24 or /home/*)
SETTINGS=(
  "username|name|"
  "IP address|value|*/24"
  "ZRAM size|size|"
  "home directory|home-directory|/home/*"
)

# Backup before modifying
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

# Prompt and apply changes using scm-utils
for entry in "${SETTINGS[@]}"; do
  IFS='|' read -r LABEL FIELD TEMPLATE <<< "$entry"

  CURRENT=$(get_value "$CONFIG_FILE" "$FIELD")
  if [[ $? -ne 0 ]]; then
    CURRENT="<not found>"
  fi

  read -rp "Enter new $LABEL (current: $CURRENT): " NEW
  NEW=${NEW:-$CURRENT}

  # Apply template transformation if specified
  if [[ "$TEMPLATE" == *"*"* ]]; then
    NEW="${TEMPLATE/\*/$NEW}"
  fi

  set_value "$CONFIG_FILE" "$FIELD" "$NEW"
done

echo "Updated '$CONFIG_FILE'. Backup saved as '${CONFIG_FILE}.bak'."
