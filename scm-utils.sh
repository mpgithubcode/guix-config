#!/bin/bash

CONFIG_FILE="config.scm"

# ─────────── Parse key path into array ───────────
parse_key_path() {
  local -n result=$1
  shift
  result=("$@")
}

# ─────────── Find matching lines for a key path ───────────
find_key_line() {
  local file="$1"
  shift
  local key_path=("$@")
  local matched=0
  local indent=""

  while IFS= read -r line; do
    for key in "${key_path[@]}"; do
      if echo "$line" | grep -q "(${key} "; then
        indent+="  "
        matched=$((matched + 1))
        break
      fi
    done

    if [[ $matched -eq ${#key_path[@]} ]]; then
      echo "$line"
      return 0
    fi
  done < "$file"

  return 1
}

# ─────────── Get value ───────────
get_value() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: get_value <file> <key> [subkey...]"
    return 1
  fi

  local file="$1"
  shift
  local key_path=()
  parse_key_path key_path "$@"

  local line
  if line=$(find_key_line "$file" "${key_path[@]}"); then
    echo "$line" | sed -nE 's/.*\(([^ ]+) "([^"]+)"\).*/\2/p'
  else
    echo "Key path not found."
    return 1
  fi
}

# ─────────── Set value ───────────
set_value() {
  if [[ $# -lt 3 ]]; then
    echo "Usage: set_value <file> <key> [subkey...] <new_value>"
    return 1
  fi

  local file="$1"
  shift
  local new_value="${@: -1}"
  local key_path=("${@:1:$#-2}")
  local tmp_file
  tmp_file=$(mktemp)

  awk -v keys="${key_path[*]}" -v new_val="$new_value" '
    BEGIN {
      split(keys, path, " ")
      path_len = length(path)
      depth = 0
    }

    function trim(str) {
      sub(/^[ \t]+/, "", str)
      return str
    }

    {
      line = $0
      trimmed = trim(line)

      # Count open/close parentheses for depth tracking
      open = gsub(/\(/, "(", line)
      close = gsub(/\)/, ")", line)
      net = open - close
      depth += net

      # Check if current line contains a matching key at current depth
      key = gensub(/^\(([^ ]+).*/, "\\1", "g", trimmed)
      if (key == path[depth]) {
        match_path[depth] = key
      }

      # If we are at the correct depth and match the final key
      if (depth == path_len && key == path[path_len]) {
        # Replace value string
        gsub(/"[^"]*"/, "\"" new_val "\"", line)
      }

      print line
    }
  ' "$file" > "$tmp_file"

  cp "$file" "${file}.bak"
  mv "$tmp_file" "$file"
  echo "Updated. Backup saved as ${file}.bak"
}
