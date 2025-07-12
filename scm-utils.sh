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
      match_depth = 0
      matched = 0
    }

    function get_key(line) {
      match(line, /^\([[:space:]]*([a-zA-Z0-9-]+)/, m)
      return m[1]
    }

    {
      line = $0
      trimmed = line
      gsub(/^[ \t]+/, "", trimmed)

      # Match each part of the key path
      if (match(trimmed, /^\([a-zA-Z0-9-]+[ \t]/)) {
        key = get_key(trimmed)

        if (key == path[match_depth + 1]) {
          match_depth++
        } else if (match_depth > 0 && key == path[match_depth]) {
          # stay at current level
        } else {
          # key does not match, reset
          match_depth = 0
        }

        # If full path matches, change the value
        if (match_depth == path_len) {
          # replace only the value string
          gsub(/"[^"]*"/, "\"" new_val "\"", line)
          matched = 1
        }
      }

      print line
    }

    END {
      if (!matched) {
        print "Warning: No matching key path found." > "/dev/stderr"
      }
    }
  ' "$file" > "$tmp_file"

  # Only overwrite if awk succeeded and file is not empty
  if [[ -s "$tmp_file" ]]; then
    cp "$file" "${file}.bak"
    mv "$tmp_file" "$file"
    echo "Updated. Backup saved as ${file}.bak"
  else
    echo "Error: resulting config was empty. Aborting."
    rm "$tmp_file"
    return 1
  fi
}
