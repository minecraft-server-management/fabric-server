# Checks if the given command exists, else fails.
#
# Arguments:
#   $1 - command to check.
#
# Examples:
#   require_command "curl"
#   require_command "jq"
require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1"
    exit 1
  }
}
