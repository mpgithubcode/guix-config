#!/bin/bash

CONFIG_FILE="config.scm"

# Source shared SCM utilities
source ./scm-utils.sh

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: '$CONFIG_FILE' not found."
  exit 1
fi

# Field label | Scheme field name | Optional post-process function name
SETTINGS=(
  "username|name|"
  "IP address|value|process_ip"
  "ZRAM size|size|"
  "home directory|home-directory|process_home"
)

# Optional post-processors
process_ip() {
  [[ "$1" == */* ]] && echo "$1" || echo "$1/24"
}

process_home() {
  echo "/home/$1"
}

# Backup before modifying
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

# Prompt and apply changes using scm-utils
for entry in "${SETTINGS[@]}"; do
  IFS='|' read -r LABEL FIELD POST_FUNC <<< "$entry"

  CURRENT=$(get_value "$CONFIG_FILE" "$FIELD")
  if [[ $? -ne 0 ]]; then
    CURRENT="<not found>"
  fi

  read -rp "Enter new $LABEL (current: $CURRENT): " NEW
  NEW=${NEW:-$CURRENT}

  # Apply transformation if needed
  if [[ -n "$POST_FUNC" ]]; then
    NEW=$($POST_FUNC "$NEW")
  fi

  set_value "$CONFIG_FILE" "$FIELD" "$NEW"
done

echo "Updated '$CONFIG_FILE'. Backup saved as '${CONFIG_FILE}.bak'."
