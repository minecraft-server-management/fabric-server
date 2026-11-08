import './_print_formatted.sh'


# Prints a debug message if debug mode is enabled.
#
# Arguments:
#   $* - Message to print
#
# Configuration:
#   CONSOLE_DEBUG=true - Enables debug output.
#
# Output:
#   Writes a gray-colored message to stdout when enabled.
console_debug() {
  local message="$*"

  [[ "$CONSOLE_DEBUG" == "true" ]] || return 0

  _print_formatted "$_COLOR_DEBUG" "$message" >&2
}
