import './_print_formatted.sh'


# Prints a regular console message without a log level or color.
#
# Arguments:
#   $1 - Message to print
#   $2 - URL link for the message
#   $3 - End character to print (default \n)
#
# Output:
#   Writes a linked message to stderr.
console_link() {
  local message="$1"
  local url="$2"
  local end="${3-$'\n'}"

  _print_formatted "\x1b]8;;${url}\x1b\\\\" "$message" "\x1b]8;;\x1b\\\\" "$end" >&2
}
