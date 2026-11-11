import './_print_formatted.sh'


# Prints a warning message.
#
# Arguments:
#   $1 - Message to print
#   $2 - End character to print (default \n)
#
# Output:
#   Writes a warning message to stderr.
console_warn() {
  local message="$1"
  local end="${2-$'\n'}"

  local COLOR_WARN='\x1b[38;5;11m'

  _print_formatted "$COLOR_WARN" "$message" "" "$end" >&2
}
