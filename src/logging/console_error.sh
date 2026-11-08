import './_print_formatted.sh'


# Prints an error message.
#
# Arguments:
#   $* - Message to print
#
# Output:
#   Writes a red-colored message to stderr.
console_error() {
  local message="$*"

  _print_formatted "$_COLOR_ERROR" "$message" >&2
}
