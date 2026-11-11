import './_print_formatted.sh'


# Prints a success message.
#
# Arguments:
#   $1 - Message to print
#   $2 - End character to print (default \n)
#
# Output:
#   Writes a success message to stderr.
console_success() {
  local message="$1"
  local end="${2-$'\n'}"

  local COLOR_SUCCESS='\x1b[38;5;10m'

  _print_formatted "$COLOR_SUCCESS" "$message" "" "$end" >&2
}
