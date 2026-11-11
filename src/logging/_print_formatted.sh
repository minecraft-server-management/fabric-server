_CONSOLE_INDENT="${CONSOLE_INDENT:-0}"
_CONSOLE_INDENT_SIZE="${CONSOLE_INDENT_SIZE:-2}"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  _COLOR_RESET='\x1b[0m'
  _COLOR_INFO='\x1b[38;5;12m'
  _COLOR_WARN='\x1b[38;5;11m'
  _COLOR_ERROR='\x1b[38;5;9m'
  _COLOR_SUCCESS='\x1b[38;5;10m'
  _COLOR_DEBUG='\x1b[38;5;245m'
else
  _COLOR_RESET=''
  _COLOR_INFO=''
  _COLOR_WARN=''
  _COLOR_ERROR=''
  _COLOR_SUCCESS=''
  _COLOR_DEBUG=''
fi

_print_formatted() {
  local color="$1"
  local message="$2"
  local end="${3-$'\n'}"

  local indent=""

  local i
  for ((i = 0; i < _CONSOLE_INDENT; i++)); do
    indent+="$(printf '%*s' "$_CONSOLE_INDENT_SIZE" '')"
  done

  printf '%b%b%b%b%s' \
    "$indent" "$color" "$message" "$_COLOR_RESET" "$end"
}
