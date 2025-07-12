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

# Store proposed changes
declare -A NEW_VALUES
declare -A CURRENT_VALUES

# Gather input
for entry in "${SETTINGS[@]}"; do
  IFS='|' read -r LABEL FIELD TEMPLATE <<< "$entry"

  CURRENT=$(get_value "$CONFIG_FILE" "$FIELD")
  if [[ $? -ne 0 ]]; then
    CURRENT="<not found>"
  fi
  CURRENT_VALUES["$FIELD"]="$CURRENT"

  read -rp "Enter new $LABEL (current: $CURRENT): " NEW
  NEW=${NEW:-$CURRENT}

  if [[ "$TEMPLATE" == *"*"* ]]; then
    NEW="${TEMPLATE/\*/$NEW}"
  fi

  NEW_VALUES["$FIELD"]="$NEW"
done

# Show summary
echo
echo "Proposed changes:"
printf "%-20s | %-30s → %-30s\n" "Field" "Current" "New"
printf -- "---------------------+--------------------------------+--------------------------------\n"
for entry in "${SETTINGS[@]}"; do
  IFS='|' read -r LABEL FIELD _ <<< "$entry"
  CURRENT="${CURRENT_VALUES[$FIELD]}"
  NEW="${NEW_VALUES[$FIELD]}"
  printf "%-20s | %-30s → %-30s\n" "$FIELD" "$CURRENT" "$NEW"
done

# Confirm
echo
read -rp "Apply these changes? [y/N]: " CONFIRM
CONFIRM=${CONFIRM,,} # lowercase

if [[ "$CONFIRM" == "y" || "$CONFIRM" == "yes" ]]; then
  for FIELD in "${!NEW_VALUES[@]}"; do
    VALUE="${NEW_VALUES[$FIELD]}"
    set_value "$CONFIG_FILE" "$FIELD" "$VALUE"
  done
  echo "Changes applied. Backup saved as '${CONFIG_FILE}.bak'."
else
  echo "No changes made."
fi
