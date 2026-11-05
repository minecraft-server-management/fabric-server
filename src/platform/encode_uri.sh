#!/usr/bin/env bash

set -euo pipefail

# Encode a string for use in a URI.
#
# Arguments:
#   $1: String to encode
#
# Returns:
#   Encoded string suitable for use in a URI.
encode_uri() {
  jq -rn --arg value "$1" '$value | @uri'
}
