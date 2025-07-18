#!/bin/bash

# ─────────── Get value ───────────
get_value() {
  local file="$1"
  local key="$2"

  grep -E "\( *$key *\"[^\"]+\" *\)" "$file" \
    | sed -nE "s/.*\($key +\"([^\"]+)\"\).*/\1/p" \
    | head -n 1
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
  local tmp_file
  tmp_file=$(mktemp)

  awk -v keys="${key_path[*]}" -v new_val="$new_value" '
    BEGIN {
      split(keys, path, " ")
      depth = 0
    }

    {
      line = $0
      trimmed = gensub(/^ +/, "", "g", line)

      # Count nesting based on keys
      if (trimmed ~ /^\(/) {
        key = gensub(/^\(([^ ]+).*/, "\\1", "g", trimmed)
        if (key == path[depth+1]) {
          current_path[depth] = key
          depth++
        }
      }

      # Replace if full path matches and value line is found
      if (depth == length(path) && trimmed ~ /^\([a-zA-Z0-9-]+ "/) {
        gsub(/"[^"]*"/, "\"" new_val "\"", line)
        depth = 0  # Reset depth to avoid accidental re-matching
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
