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

  unzip -p "$mrpack_path" modrinth.index.json | jq -c '.files[]' | while IFS= read -r entry; do
    local url
    url=$(echo "$entry" | jq -r '.downloads[0]')

    local project_id version_id
    project_id=$(echo "$url" | sed -n 's|.*/data/\([^/]\{8\}\)/versions/.*|\1|p')
    version_id=$(echo "$url" | sed -n 's|.*/versions/\([^/]\{8\}\)/.*|\1|p')

    local name
    name=$(curl -s "https://api.modrinth.com/v2/project/${project_id}" | jq -r '.title')

    local file_name
    file_name=$(echo "$entry" | jq -r '.path | split("/") | last')

    jq -cn \
      --arg id "$project_id" \
      --arg version "$version_id" \
      --arg name "$name" \
      --arg url "$url" \
      --arg fileName "$file_name" \
      '{id: $id, version: $version, name: $name, url: $url, fileName: $fileName, dependencies: []}'
  done | jq -s '.'
}
