#!/bin/bash

declare -a CONTEXT_STACK=()

update_context() {
  local line="$1"
  local open_count close_count i key

  # Count '(' and ')' in line
  open_count=$(grep -o "(" <<< "$line" | wc -l)
  close_count=$(grep -o ")" <<< "$line" | wc -l)

  # Extract keys after '(' e.g. (name
  local rest="$line"
  local re='\(([a-zA-Z0-9_-]+)'

  while [[ $rest =~ $re ]]; do
    key="${BASH_REMATCH[1]}"
    CONTEXT_STACK+=("$key")
    rest="${rest#*\($key}"
  done

  # Remove keys for each ')'
  for ((i=0; i<close_count; i++)); do
    if ((${#CONTEXT_STACK[@]} > 0)); then
      unset 'CONTEXT_STACK[-1]'
    fi
  done
}

get_current_path() {
  echo "${CONTEXT_STACK[*]}"
}

join_path() {
  local joined=""
  for key in "$@"; do
    [[ -n "$joined" ]] && joined+=" "
    joined+="$key"
  done
  echo "$joined"
}

path_matches() {
  local target_path="$1"
  local candidate_key="$2"

  local current_path
  current_path="$(get_current_path)"
  local full_path="$current_path $candidate_key"

  if [[ "$full_path" == "$target_path" ]]; then
    return 0
  else
    return 1
  fi
}

find_value_by_key_path() {
  local file="$1"
  shift
  local -a target_path=("$@")
  local target_path_str
  target_path_str="$(join_path "${target_path[@]}")"

  CONTEXT_STACK=()

  while IFS= read -r line || [[ -n $line ]]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^\s*;; ]] && continue
    [[ -z "$line" ]] && continue

    update_context "$line"

    # Look for pattern (key "value")
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

# Simple alias for clarity
get_value() {
  find_value_by_key_path "$@"
}
