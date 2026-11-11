import './_print_formatted.sh'


# Prints a debug message if debug mode is enabled.
#
# Arguments:
#   $1 - Message to print
#   $2 - End character to print (default \n)
#
# Configuration:
#   CONSOLE_DEBUG=true - Enables debug output.
#
# Output:
#   Writes a debug message to stderr when enabled.
console_debug() {
  [[ "$CONSOLE_DEBUG" == "true" ]] || return 0

  local message="$1"
  local end="${2-$'\n'}"

  local COLOR_DEBUG='\x1b[38;5;245m'

  _print_formatted "$COLOR_DEBUG" "$message" "" "$end" >&2
}
