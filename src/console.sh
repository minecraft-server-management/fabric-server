#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ! -p "$SERVER_FIFO" ]]; then
  console_error 'Server console pipe not found.'
  exit 1
fi

if [[ $# -eq 0 ]]; then
  console_log 'Usage: console <command>'
  exit 2
fi

printf '%s\n' "$*" > "$SERVER_FIFO"
