#!/bin/bash

CONFIG_FILE="config.scm"

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

# Backup before modifying
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

# Temporary sed script
SED_SCRIPT=$(mktemp)

# Optional post-processors
process_ip() {
  [[ "$1" == */* ]] && echo "$1" || echo "$1/24"
}

process_home() {
  echo "/home/$1"
}

for entry in "${SETTINGS[@]}"; do
  IFS='|' read -r LABEL FIELD POST_FUNC <<< "$entry"

  # Extract current value using grep/sed
  REGEX="\\($FIELD \\\"\\(.*\\)\\\"\\)"
  CURRENT=$(grep -m1 "($FIELD \"" "$CONFIG_FILE" | sed -E "s/.*$REGEX.*/\2/")

  # Prompt
  read -rp "Enter new $LABEL (current: $CURRENT): " NEW
  NEW=${NEW:-$CURRENT}

  # Optional transformation
  if [[ -n "$POST_FUNC" ]]; then
    NEW=$($POST_FUNC "$NEW")
  fi

  # Append to sed script
  echo "s|($FIELD \"[^\"]*\")|($FIELD \"$NEW\")|" >> "$SED_SCRIPT"
done

# Apply changes
sed -i -E -f "$SED_SCRIPT" "$CONFIG_FILE"
rm "$SED_SCRIPT"

echo "Updated '$CONFIG_FILE'. Backup saved as '${CONFIG_FILE}.bak'."
