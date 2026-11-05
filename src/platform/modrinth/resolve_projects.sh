#!/usr/bin/env bash

set -Eeuo pipefail

import "../../logging.sh"
import "./api_get.sh"
import "../encode_uri.sh"


# Configuration
MODRINTH_API="${MODRINTH_API:-https://api.modrinth.com/v2}"
MODRINTH_LOADER="${MODRINTH_LOADER:-fabric}"

USER_AGENT="ghcr.io/minecraft-server-management/fabric-server"

# Globals
declare -A RESOLVED_PROJECT_NODES=()
declare -A IN_PROGRESS_PROJECTS=()


# Resolve a single project and its dependencies into a JSON tree node.
# 
# Arguments:
#   $1: Minecraft version
#   $2: Project ID
#   $3: Optional pinned version (if empty, the latest compatible version is used)
#   $4: Optional allowed dependency types (comma-separated, default: "required")
#
# Returns:
#   JSON object representing the project and its dependencies.
_resolve_project() {
  local minecraft_version="$1"
  local project_id="$2"
  local pinned_version="${3:-}"
  local allowed_dependencies="${4:-required}"

  if [[ -n "${RESOLVED_PROJECT_NODES[$project_id]+x}" ]]; then
    echo "${RESOLVED_PROJECT_NODES[$project_id]}"
    return

  fi

  if [[ -n "${IN_PROGRESS_PROJECTS[$project_id]+x}" ]]; then
    echo "null"
    return

  fi

  IN_PROGRESS_PROJECTS["$project_id"]=1

  local project_info
  local project_name
  local encoded_game_versions
  local encoded_loaders
  local encoded_version_numbers
  local project_version
  local api_endpoint
  local project_version_number
  local project_file_url
  local project_file_name

  project_info=$(api_get "/project/${project_id}")

  project_name=$(echo "$project_info" | jq -r '.title')
  encoded_game_versions=$(encode_uri "[\"${minecraft_version}\"]")
  encoded_loaders=$(encode_uri "[\"${MODRINTH_LOADER}\"]")
  api_endpoint="/project/${project_id}/version?game_versions=${encoded_game_versions}&loaders=${encoded_loaders}"

  # Pin version if specified
  if [[ -n "$pinned_version" ]]; then
    encoded_version_numbers=$(encode_uri "[\"${pinned_version}\"]")
    api_endpoint="/project/${project_id}/version?game_versions=${encoded_game_versions}&loaders=${encoded_loaders}&version_numbers=${encoded_version_numbers}"
  fi

  project_version=$(api_get "$api_endpoint")

  # Empty array -> no compatible version found
  if [[ "$(echo "$project_version" | jq 'length')" == "0" ]]; then
    console_error "No version found for '${project_id}' (mc=${minecraft_version}, loader=${MODRINTH_LOADER})"
    unset "IN_PROGRESS_PROJECTS[$project_id]"
    return 1
  fi

  project_version_number=$(echo "$project_version" | jq -r '.[0].version_number')
  project_file_url=$(echo "$project_version" | jq -r '.[0].files[0].url')
  project_file_name=$(echo "$project_version" | jq -r '.[0].files[0].filename')

  local -a allowed_types=()
  IFS=',' read -ra allowed_types <<< "$allowed_dependencies"

  local -a dependency_trees=()
  while IFS= read -r dependency; do
    local dependency_id
    local dependency_type

    dependency_id=$(echo "$dependency" | jq -r '.project_id')
    dependency_type=$(echo "$dependency" | jq -r '.dependency_type')

    [[ "$dependency_id" == "null" || -z "$dependency_id" ]] && continue


    local allowed=false
    for allowed_type in "${allowed_types[@]}"; do
      [[ "$dependency_type" == "$allowed_type" ]] && allowed=true && break
    done
    $allowed || continue

    local dependency_tree
    dependency_tree=$(_resolve_project "$minecraft_version" "$dependency_id" "" "$allowed_dependencies")
    [[ "$dependency_tree" == "null" ]] && continue

    dependency_trees+=("$dependency_tree")

  done < <(echo "$project_version" | jq -c '.[0].dependencies[]')

  local dependency_json
  if (( ${#dependency_trees[@]} == 0 )); then
    dependency_json="[]"

  else
    dependency_json=$(printf '%s\n' "${dependency_trees[@]}" | jq -s '.')

  fi

  local project_node
  project_node=$(jq -cn \
    --arg id "$project_id" \
    --arg version "$project_version_number" \
    --arg name "$project_name" \
    --arg url "$project_file_url" \
    --arg fileName "$project_file_name" \
    --argjson dependencies "$dependency_json" \
    '{id: $id, version: $version, name: $name, url: $url, fileName: $fileName, dependencies: $dependencies}')

  RESOLVED_PROJECT_NODES["$project_id"]="$project_node"
  unset "IN_PROGRESS_PROJECTS[$project_id]"

  echo "$project_node"
}


resolve_projects() {
  local minecraft_version="$1"
  local mods_json="$2"

  local -a root_nodes=()

  while IFS= read -r mod; do
    local id
    local version
    local dependency_type
    local node

    id=$(echo "$mod" | jq -r '.id')
    version=$(echo "$mod" | jq -r '.version // empty')
    dependency_type=$(echo "$mod" | jq -r '.downloadDependencies // "required"')

    node=$(_resolve_project "$minecraft_version" "$id" "$version" "$dependency_type")
    
    root_nodes+=("$node")

  done < <(echo "$mods_json" | jq -c '.[]')

  if (( ${#root_nodes[@]} == 0 )); then
    echo "[]"

  else
    printf '%s\n' "${root_nodes[@]}" | jq -s '.'

  fi
}
