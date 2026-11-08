import './_print_formatted.sh'


# Opens or closes a console group.
#
# Arguments:
#   $1 - Optional group name.
#
# Behavior:
#   - When a group name is provided, prints the group name and
#     increases the indentation level.
#   - When called without an argument, decreases the indentation
#     level and closes the current group.
#   - Indentation will never become negative.
#
# Examples:
#   console_group "Installing mods"
#   console_group
console_group() {
  local name="${1:-}"

  if [[ -n "$name" ]]; then
    _print_formatted "" "[$name]" >&2
    _CONSOLE_INDENT=$((_CONSOLE_INDENT + 1))
  else
    if (( _CONSOLE_INDENT > 0 )); then
      _CONSOLE_INDENT=$((_CONSOLE_INDENT - 1))
    else
      _CONSOLE_INDENT=0
    fi
  fi
}
