#!/usr/bin/env bash
set -e

CONSOLE_FIFO="/tmp/console.fifo"

if [[ ! -p "$CONSOLE_FIFO" ]]; then
  echo "Minecraft console pipe not found." >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  echo "Usage: console <command>" >&2
  exit 2
fi

printf '%s\n' "$*" > "$CONSOLE_FIFO"
