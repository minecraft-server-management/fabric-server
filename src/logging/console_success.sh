import './_print_formatted.sh'


# Prints a success message.
#
# Arguments:
#   $* - Message to print
#
# Output:
#   Writes a green-colored message to stdout.
console_success() {
  local message="$*"

  _print_formatted "$_COLOR_SUCCESS" "$message" >&2
}
