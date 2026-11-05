#!/usr/bin/env bash
#
# logging.sh
#
# Description:
#   Provides a centralized console logging utility for Bash scripts.
#   Supports colored log messages, configurable indentation and
#   nested console groups.
#
# Features:
#   - Log levels: log, info, warn, error, success and debug.
#   - ANSI color support with automatic TTY detection.
#   - Respects the NO_COLOR environment variable.
#   - Configurable group indentation.
#   - Nested console groups.
#   - Optional debug output.
#   - Prevents multiple imports.
#
# Configuration:
#   CONSOLE_INDENT       Initial indentation level (default: 0).
#   CONSOLE_INDENT_SIZE  Spaces per indentation level (default: 2).
#   CONSOLE_DEBUG        Enables debug output (default: false).
#   NO_COLOR             Disables colored output when set.
#
# Usage:
#   source /app/logging.sh
#
#   console_info "Starting installation"
#   console_group "Downloading mods"
#     console_success "Mod downloaded"
#   console_group
#

set -Eeuo pipefail

# Prevent multiple imports
if [[ -n "${_LOGGING_SH_LOADED:-}" ]]; then
  return 0
fi
_LOGGING_SH_LOADED=1

# Configuration
CONSOLE_INDENT="${CONSOLE_INDENT:-0}"
CONSOLE_INDENT_SIZE="${CONSOLE_INDENT_SIZE:-2}"
CONSOLE_DEBUG="${CONSOLE_DEBUG:-false}"

# Colors
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

# Prints a formatted console message.
#
# Arguments:
#   $1 - ANSI color code
#   $2 - Message to print
#
# Behavior:
#   - Applies the current group indentation.
#   - Applies the specified ANSI color.
#   - Resets the terminal color after the message.
_print_in_color() {
  local color="$1"
  local message="$2"

  local indent=""
  local i

  for ((i = 0; i < CONSOLE_INDENT; i++)); do
    indent+="$(printf '%*s' "$CONSOLE_INDENT_SIZE" '')"
  done

  printf '%s%b%s%b\n' \
    "$indent" "$color" "$message" "$_COLOR_RESET"
}

# Prints a regular console message without a log level or color.
#
# Arguments:
#   $@ - Message to print
#
# Output:
#   Writes the message to stdout.
console_log() {
  _print_in_color "" "$*"
}

# Prints an informational console message.
#
# Arguments:
#   $@ - Message to print
#
# Output:
#   Writes a cyan-colored message to stdout.
console_info() {
  _print_in_color "$_COLOR_INFO" "$*"
}

# Prints a warning message.
#
# Arguments:
#   $@ - Message to print
#
# Output:
#   Writes a yellow-colored message to stderr.
console_warn() {
  _print_in_color "$_COLOR_WARN" "$*" >&2
}

# Prints an error message.
#
# Arguments:
#   $@ - Message to print
#
# Output:
#   Writes a red-colored message to stderr.
console_error() {
  _print_in_color "$_COLOR_ERROR" "$*" >&2
}

# Prints a success message.
#
# Arguments:
#   $@ - Message to print
#
# Output:
#   Writes a green-colored message to stdout.
console_success() {
  _print_in_color "$_COLOR_SUCCESS" "$*"
}

# Prints a debug message if debug mode is enabled.
#
# Arguments:
#   $@ - Message to print
#
# Configuration:
#   CONSOLE_DEBUG=true - Enables debug output.
#
# Output:
#   Writes a gray-colored message to stdout when enabled.
console_debug() {
  [[ "$CONSOLE_DEBUG" == "true" ]] || return 0
  _print_in_color "$_COLOR_DEBUG" "$*"
}

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
    _print_in_color "" "[$name]"
    CONSOLE_INDENT=$((CONSOLE_INDENT + 1))
  else
    if (( CONSOLE_INDENT > 0 )); then
      CONSOLE_INDENT=$((CONSOLE_INDENT - 1))
    fi
  fi
}

# Closes all currently open console groups.
#
# Behavior:
#   Resets the indentation level to zero.
#
# Example:
#   console_group_close_all
console_group_close_all() {
  CONSOLE_INDENT=0
}
