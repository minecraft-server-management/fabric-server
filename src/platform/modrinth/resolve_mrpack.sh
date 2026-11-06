#!/usr/bin/env bash

set -Eeuo pipefail

import "../../logging.sh"


# Parse a Modrinth .mrpack archive.
#
# Arguments:
#   $1: Path to .mrpack
#
# Returns:
#   JSON object array representing the project and its dependencies.
api_get() {
  local mrpack_path="$1"

  console_debug "Path to .mrpack: '$mrpack_path'"
}
