#!/usr/bin/env bash

set -Eeuo pipefail

import "../../logging.sh"


# Resolve a modrinth .mrpack into a JSON tree.
# 
# Arguments:
#   $1: Path to .mrpack
#
# Returns:
#   JSON object array representing the projects and their dependencies.
resolve_mrpack() {
  local mrpack_path="$1"

  console_debug "Path to .mrpack: '$mrpack_path'"
}
