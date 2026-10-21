#!/usr/bin/env bash
set -Eeuo pipefail

HOST="${HEALTHCHECK_HOST:-127.0.0.1}"
PORT="${SERVER_PORT:-25565}"

if ! [[ "$PORT" =~ ^[0-9]+$ ]] ||
  (( PORT < 1 || PORT > 65535 )); then
  exit 1
fi

exec nc -z -w 3 "$HOST" "$PORT"
