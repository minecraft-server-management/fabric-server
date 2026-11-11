import './_print_formatted.sh'


# Prints an error message.
#
# Arguments:
#   $1 - Message to print
#   $2 - End character to print (default \n)
#
# Output:
#   Writes an error message to stderr.
console_error() {
  local message="$1"
  local end="${2-$'\n'}"

  _print_formatted "$_COLOR_ERROR" "$message" "$end" >&2
}
