#!/bin/bash

# Global variable holding current nested context stack (array)
declare -a CONTEXT_STACK=()

# ------------------------
# 1. update_context()
#    Reads a line, updates CONTEXT_STACK by pushing or popping keys
# Usage: update_context "line"
# ------------------------
update_context() {
  local line="$1"
  # Count opening and closing parentheses in line
  local open_count close_count i key

  open_count=$(grep -o "(" <<< "$line" | wc -l)
  close_count=$(grep -o ")" <<< "$line" | wc -l)

  # Extract keys from opening parentheses like (key or (key(
  # Use regex to extract all keys at start of '(' groups
  # We'll use a while loop to find all (key occurrences from left to right

  # Extract keys in line matching pattern: '(' followed by key chars
  # We'll loop using bash regex until no match found

  local rest="$line"
  local re='\(([a-zA-Z0-9_-]+)'

  while [[ $rest =~ $re ]]; do
    key="${BASH_REMATCH[1]}"
    CONTEXT_STACK+=("$key")
    # Remove the part before and including matched key
    rest="${rest#*\($key}"
  done

  # Pop keys for each closing paren (could be nested multiple)
  for ((i=0; i<close_count; i++)); do
    if ((${#CONTEXT_STACK[@]} > 0)); then
      unset 'CONTEXT_STACK[-1]'
    fi
  done
}

# ------------------------
# 2. get_current_path()
#    Returns the current full nested path as a space-separated string
# Usage: get_current_path
# ------------------------
get_current_path() {
  echo "${CONTEXT_STACK[*]}"
}

# ------------------------
# 3. path_matches()
#    Compares current path + a candidate key with a target path string
# Usage: path_matches <target_path_string> <candidate_key>
# Returns 0 (success) if matches, 1 if not
# ------------------------
path_matches() {
  local target_path="$1"
  local candidate_key="$2"

  local current_path
  current_path="$(get_current_path)"
  local full_path="$current_path $candidate_key"

  # Normalize spaces for exact match
  if [[ "$full_path" == "$target_path" ]] || [[ "$current_path" == "$target_path" ]]; then
    return 0
  else
    return 1
  fi
}

# ------------------------
# 4. find_value_by_key_path()
#    Reads a file line-by-line, updates context, searches for key's value
# Usage: find_value_by_key_path <file> <key1> [key2 ... keyN]
# ------------------------
get_value() {
  local file="$1"
  shift
  local -a target_path=("$@")
  local target_path_str
  target_path_str="$(join_path "${target_path[@]}")"

  # Reset CONTEXT_STACK before reading file
  CONTEXT_STACK=()

  while IFS= read -r line || [[ -n $line ]]; do
    update_context "$line"

    # Look for key-value pattern in the line: (key "value")
    # Extract key and value from this line
    if [[ "$line" =~ \(([a-zA-Z0-9_-]+)[[:space:]]+\"([^\"]+)\"\) ]]; then
      local key="${BASH_REMATCH[1]}"
      local val="${BASH_REMATCH[2]}"
      if path_matches "$target_path_str" "$key"; then
        echo "$val"
        return 0
      fi
    fi
  done < "$file"

  return 1
}

# ------------------------
# 5. join_path()
#    Helper: joins an array of keys into a space-separated string
# Usage: join_path key1 key2 key3 ...
# ------------------------
join_path() {
  local joined=""
  for key in "$@"; do
    [[ -n "$joined" ]] && joined+=" "
    joined+="$key"
  done
  echo "$joined"
}
