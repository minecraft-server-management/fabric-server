#!/usr/bin/env bash

set -Eeuo pipefail

# Perform a GET request to the Modrinth API.
#
# Arguments:
#   $1: API endpoint (e.g., "/project/{project_id}")
#
# Returns:
#   JSON response from the API.
api_get() {
  local endpoint="$1"

  curl \
    --globoff \
    --fail \
    --silent \
    --show-error \
    --retry 3 \
    --retry-delay 1 \
    --user-agent "${USER_AGENT}" \
    "${MODRINTH_API}${endpoint}"
}
