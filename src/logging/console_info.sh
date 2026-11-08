import './_print_formatted.sh'


# Prints an informational console message.
#
# Arguments:
#   $* - Message to print
#
# Output:
#   Writes a cyan-colored message to stdout.
console_info() {
  local message="$*"

  _print_formatted "$_COLOR_INFO" "$message" >&2
}
