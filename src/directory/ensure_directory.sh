#!/usr/bin/env bash

set -euo pipefail

import '../logging.sh'

# Ensures that the specified directory path exists.
# If $2 is not set, the directory gets created, else exits and logs the error message
#
# Arguments:
#   $1: Path to the directory
#   $2: (Optional) Error message to log if the directory does not exist
ensure_directory() {
  local path="$1"
  local error_message="$2"

  if [[ -d "$path" ]]; then
    return 0
  fi

  if [[ -n "$error_message" ]]; then
    console_error "$error_message"
    return 1
  fi

  mkdir -p -- "$path"
}
