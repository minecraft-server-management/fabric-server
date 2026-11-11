import './_print_formatted.sh'


# Prints an informational console message.
#
# Arguments:
#   $1 - Message to print
#   $2 - End character to print (default \n)
#
# Output:
#   Writes an info message to stderr.
console_info() {
  local message="$1"
  local end="${2-$'\n'}"

  _print_formatted "$_COLOR_INFO" "$message" "$end" >&2
}
