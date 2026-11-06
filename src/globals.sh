

# Tracks imported Bash scripts.
declare -gA _IMPORT_LOADED_FILES=()

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
    echo "Import path is required"
    return 1
  }

  local caller_dir
  local import_dir
  local import_path

  caller_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[1]}")" && pwd -P)" || return 1

  import_dir="$(cd -- "${caller_dir}/$(dirname -- "${relative_path}")" 2>/dev/null && pwd -P)" || {
    echo "Cannot resolve import path: ${relative_path}"
    return 1
  }

  import_path="${import_dir}/$(basename -- "${relative_path}")"

  [[ -f "${import_path}" && -r "${import_path}" ]] || {
    echo "Cannot import '${relative_path}': file not found or not readable"
    return 1
  }

  # Skip already imported scripts.
  if [[ -n "${_IMPORT_LOADED_FILES[$import_path]+x}" ]]; then
    return 0
  fi

  _IMPORT_LOADED_FILES["${import_path}"]=1

  source "${import_path}"
}
