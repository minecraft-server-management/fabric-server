#!/usr/bin/env bash

set -Eeuo pipefail

# Extract all unique project IDs from the dependency tree
#
# Arguments:
#   $1: JSON tree (the output of resolve_projects)
#
# Returns:
#   One project ID per line on stdout
get_project_ids() {
  echo "$1" | jq -r '[.. | .id? // empty] | unique[]'
}
