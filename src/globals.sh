#!/usr/bin/env bash
set -Eeuo pipefail


# Tracks imported Bash scripts.
declare -gA _IMPORT_LOADED_FILES=()

# Prints an import error message with the file and line number of the import() call site.
#
# Arguments:
#   $1 - Error message.
_print_import_error() {
  local msg="${1:-}"
  local file line

  # BASH_SOURCE[2]/BASH_LINENO[1] = call site of import().
  file="${BASH_SOURCE[2]:-unknown}"
  line="${BASH_LINENO[1]:-0}"

  echo -e "\x1b[38;5;9m${file}: line ${line}: ${msg}\x1b[0m" >&2
}

# Imports a Bash script relative to pwd.
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
    _print_import_error "Import path is required"
    return 1
  }

  local caller_dir
  local import_dir
  local import_path

  caller_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[1]}")" && pwd -P)" || return 1

  import_dir="$(cd -- "${caller_dir}/$(dirname -- "${relative_path}")" 2>/dev/null && pwd -P)" || {
    _print_import_error "'${relative_path}': cannot resolve import path"
    return 1
  }

  import_path="${import_dir}/$(basename -- "${relative_path}")"

  [[ -f "${import_path}" && -r "${import_path}" ]] || {
    _print_import_error "'${relative_path}': file not found or not readable"
    return 1
  }

  if [[ -n "${_IMPORT_LOADED_FILES[$import_path]+x}" ]]; then
    return 0
  fi

  _IMPORT_LOADED_FILES["${import_path}"]=1

  source "${import_path}"
}
