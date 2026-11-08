import './_print_formatted.sh'


# Prints a regular console message without a log level or color.
#
# Arguments:
#   $* - Message to print
#
# Output:
#   Writes a message to stdout.
console_log() {
  local message="$*"

  _print_formatted "" "$message" >&2
}
