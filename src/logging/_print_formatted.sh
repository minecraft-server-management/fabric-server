_print_formatted() {
  local prefix="$1"
  local message="$2"
  local suffix="${3:-$'\x1b[0m'}"
  local end="${4-$'\n'}"

  _CONSOLE_INDENT="${CONSOLE_INDENT:-0}"
  _CONSOLE_INDENT_SIZE="${CONSOLE_INDENT_SIZE:-2}"

  if [[ -n "${NO_COLOR:-}" ]]; then
    prefix=""
    suffix=""
  fi

  local indent
  printf -v indent '%*s' "$((_CONSOLE_INDENT * _CONSOLE_INDENT_SIZE))" ''

  printf '%b%b%b%b%s' \
    "$indent" "$prefix" "$message" "$suffix" "$end"
}
