#!/usr/bin/env bash

source /app/logging.sh

# Imports a Bash script relative to /app.
#
# Arguments:
#   $1 - Relative path to the Bash script.
#
# Examples:
#   import "logging.sh"
#   import "platform/modrinth/utils.sh"
#   import "platform/modrinth/../../logging.sh"
import() {
  local relative_path="${1:-}"

  [[ -n "${relative_path}" ]] || {
    console_error "Import path is required"
    return 1
  }

  local caller_dir
  local import_dir
  local import_file
  local import_path

  caller_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[1]}")" && pwd -P)" || return 1

  import_dir="$(dirname -- "${relative_path}")"
  import_file="$(basename -- "${relative_path}")"

  import_dir="$(cd -- "${caller_dir}/${import_dir}" 2>/dev/null && pwd -P)" || {
    console_error "Cannot resolve import path: ${relative_path}"
    return 1
  }

  import_path="${import_dir}/${import_file}"

  case "${import_path}" in
    /app/*) ;;
    *)
      console_error "Import path is outside /app: ${relative_path}"
      return 1
    ;;
  esac

  [[ -f "${import_path}" && -r "${import_path}" ]] || {
    console_error "Cannot import '${relative_path}': file not found or not readable"
    return 1
  }

  source "${import_path}"
}
