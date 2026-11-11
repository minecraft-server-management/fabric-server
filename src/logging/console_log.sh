import './_print_formatted.sh'


# Prints a regular console message without a log level or color.
#
# Arguments:
#   $1 - Message to print
#   $2 - End character to print (default \n)
#
# Output:
#   Writes a normal message to stderr.
console_log() {
  local message="$1"
  local end="${2-$'\n'}"

  _print_formatted "" "$message" "" "$end" >&2
}
