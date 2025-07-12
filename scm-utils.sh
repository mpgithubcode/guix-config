#!/bin/bash

CONFIG_FILE="config.scm"

# ─────────── Get value ───────────
get_value() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: get_value <file> <key> [subkey...]"
    return 1
  fi

  local file="$1"
  shift
  local key_path=("$@")
  local indent=""
  local matched=0

  # Read the file line-by-line, matching nested keys
  while IFS= read -r line; do
    for key in "${key_path[@]}"; do
      if echo "$line" | grep -q "(${key} "; then
        indent+="  "
        matched=$((matched + 1))
        break
      fi
    done

    # Match value once full path has been matched
    if [[ $matched -eq ${#key_path[@]} ]]; then
      echo "$line" | sed -nE 's/.*\(([^ ]+) "([^"]+)"\).*/\2/p'
      return 0
    fi
  done < "$file"

  echo "Key path not found."
  return 1
}

# ─────────── Set value ───────────
set_value() {
  if [[ $# -lt 3 ]]; then
    echo "Usage: set_value <file> <key> [subkey...] <new_value>"
    return 1
  fi

  local file="$1"
  shift
  local new_value="${@: -1}"              # Last argument
  local key_path=("${@:1:$#-2}")          # All but last two
  local depth=0
  local current_path=()
  local tmp_file
  tmp_file=$(mktemp)

  awk -v keys="${key_path[*]}" -v new_val="$new_value" '
    BEGIN {
      split(keys, path, " ")
      depth = 0
    }

    {
      line = $0
      # Trim leading spaces
      trimmed = gensub(/^ +/, "", "g", line)

      # Track depth
      if (trimmed ~ /^\(/) {
        key = gensub(/^\(([^ ]+).*/, "\\1", "g", trimmed)
        if (key == path[depth+1]) {
          current_path[depth] = key
          depth++
        }
      }

      # If full path matched and line contains the key to change
      if (depth == length(path) && trimmed ~ /^\([a-zA-Z0-9-]+ "/) {
        # Replace value
        gsub(/"[^"]*"/, "\"" new_val "\"", line)
        depth = 0  # Reset after change
      }

      print line
    }
  ' "$file" > "$tmp_file"

  cp "$file" "${file}.bak"
  mv "$tmp_file" "$file"
  echo "Updated. Backup saved as ${file}.bak"
}
