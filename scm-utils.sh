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
      in_match = 0
    }

    function trim(str) {
      sub(/^[ \t]+/, "", str)
      return str
    }

    function get_key(str,   m) {
      match(str, /^\(([a-zA-Z0-9-]+)[ \t)]/, m)
      return m[1]
    }

    {
      line = $0
      trimmed = trim(line)
      key = get_key(trimmed)

      if (in_match == 0 && key == path[1]) {
        match_depth = 1
        in_match = 1
      } else if (in_match == 1 && match_depth < path_len && key == path[match_depth+1]) {
        match_depth++
      }

      # Only replace if full key path matched
      if (in_match == 1 && match_depth == path_len && key == path[path_len]) {
        if (trimmed ~ /^\([a-zA-Z0-9-]+[ \t]+"[^"]+"\)/) {
          gsub(/"[^"]*"/, "\"" new_val "\"", line)
          in_match = 0
          match_depth = 0
        }
      }

      print line
    }
  ' "$file" > "$tmp_file"

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
