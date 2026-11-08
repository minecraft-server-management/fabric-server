import './_print_formatted.sh'


# Prints a warning message.
#
# Arguments:
#   $* - Message to print
#
# Output:
#   Writes a yellow-colored message to stderr.
console_warn() {
  local message="$*"

  _print_formatted "$_COLOR_WARN" "$message" >&2
}
