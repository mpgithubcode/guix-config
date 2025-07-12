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
      current_depth = 0
    }

    function trim(str) {
      sub(/^[ \t]+/, "", str)
      return str
    }

    function get_key(str,   m) {
      match(str, /^\(([a-zA-Z0-9-]+)[ \t]/, m)
      return m[1]
    }

    {
      line = $0
      trimmed = trim(line)

      # Try to match keys along the path
      if (match(trimmed, /^\([a-zA-Z0-9-]+[ \t]/)) {
        key = get_key(trimmed)

        # If we’re matching the expected key at current depth
        if (key == path[current_depth + 1]) {
          current_depth++
        } else if (current_depth > 0 && key == path[current_depth]) {
          # do nothing, still at valid depth
        } else {
          # mismatch, reset
          current_depth = 0
        }

        # If this is the final match and the actual key is correct
        if (current_depth == path_len && key == path[path_len]) {
          gsub(/"[^"]*"/, "\"" new_val "\"", line)
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
