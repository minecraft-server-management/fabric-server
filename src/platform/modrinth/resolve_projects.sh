import '../../logging/console_error.sh'
import '../../logging/console_debug.sh'
import '../../logging/console_group.sh'
import './api_get.sh'
import './get_project_slug.sh'
import '../encode_uri.sh'
import './is_valid_project_id.sh'


# Configuration
MODRINTH_LOADER="${MODRINTH_LOADER:-fabric}"


# Globals
declare -gA PROJECTS_RESOLVED=()
declare -gA PROJECTS_IN_PROGRESS=()


# Resolve a single project and its dependencies into a JSON tree node.
# 
# Arguments:
#   $1 - Minecraft version
#   $2 - Project ID
#   $3 - (Optional) Pinned version (if empty, the latest compatible version is used)
#   $4 - (Optional) Dependencies to resolve, can be "none", "optional" or "required" (default: "required")
#
# Returns:
#   JSON object representing the project and its dependencies.
_resolve_project() {
  local minecraft_version="$1"
  local project_id="$2"
  local project_version_pinned="${3:-}"
  local resolve_dependencies="${4:-required}"

  is_valid_project_id "$project_id" || {
    console_warn "Project ID '$project_id' is not a valid Modrinth project ID, skipping ..."
    echo "null"
    return 0
  }

  project_id="$(get_project_slug "$project_id")"

  if [[ ${PROJECTS_RESOLVED[$project_id]+x} && "$resolve_dependencies" == "none" ]]; then
    echo "${PROJECTS_RESOLVED[$project_id]}"
    return

  fi

  if [[ ${PROJECTS_IN_PROGRESS[$project_id]+x} ]]; then
    echo "null"
    return

  fi

  local project_info
  project_info=$(api_get "/project/${project_id}")

  local project_name
  project_name=$(echo "$project_info" | jq -r '.title')
  
  local encoded_game_versions
  encoded_game_versions=$(encode_uri "[\"${minecraft_version}\"]")

  local encoded_loaders
  encoded_loaders=$(encode_uri "[\"${MODRINTH_LOADER}\"]")
  
  

  local project_versions
  
  # Pin version if specified
  if [[ -n "$project_version_pinned" ]]; then
    project_versions="$(api_get "/project/${project_id}/version/${project_version_pinned}")" || {
      console_warn "Unable to resolve provided version '$project_version_pinned' for project ID '$project_id', skipping ..."
      echo "null"
      return 0
    }

    project_versions="[$project_versions]"
  else
    project_versions="$(api_get "/project/${project_id}/version?game_versions=${encoded_game_versions}&loaders=${encoded_loaders}")" || {
      console_warn "Unable to get latest version for project ID '$project_id', skipping ..."
      echo "null"
      return 0
    }
  fi

  local project_url
  # Empty array -> no compatible version found
  if [[ "$(echo "$project_versions" | jq 'length')" == "0" ]]; then
    console_warn "No version found for project ID '${project_id}', skipping ..."
    echo "null"
    return 0
  fi

  local project_version_number
  project_version_number=$(echo "$project_versions" | jq -r '.[0].version_number')
  
  local project_file_url
  project_file_url=$(echo "$project_versions" | jq -r '.[0].files[0].url')
  
  local project_file_name
  project_file_name=$(echo "$project_versions" | jq -r '.[0].files[0].filename')
  
  project_url="https://modrinth.com/project/${project_id}/version/${project_version_number}"

  PROJECTS_IN_PROGRESS["$project_id"]=1
  
  local dependency_json="[]"

  if [[ "$resolve_dependencies" != "none" ]]; then

    local -a dependency_trees=()
    while IFS= read -r dependency; do
      local dependency_id
      dependency_id=$(get_project_slug "$(echo "$dependency" | jq -r '.project_id')")

      local dependency_type
      dependency_type=$(echo "$dependency" | jq -r '.dependency_type')

      local dependency_version=""

      if [[ ${PROJECTS_RESOLVED[$dependency_id]+x} ]]; then
        dependency_version=$(echo "${PROJECTS_RESOLVED[$dependency_id]}" | jq -r '.version_number')
      fi

      [[ "$dependency_id" == "null" || -z "$dependency_id" ]] && continue

      [[ "$dependency_type" != "$resolve_dependencies" ]] && continue

      local dependency_tree
      dependency_tree=$(_resolve_project "$minecraft_version" "$dependency_id" "$dependency_version" "$resolve_dependencies")
      [[ "$dependency_tree" == "null" ]] && continue

      dependency_trees+=("$dependency_tree")

    done < <(echo "$project_versions" | jq -c '.[0].dependencies // [] | .[]')

    if (( ${#dependency_trees[@]} > 0 )); then
      dependency_json=$(echo "${dependency_trees[@]}" | jq -s '.')
    fi
  fi

  local project_node
  project_node=$(jq -cn \
    --arg project_id "$project_id" \
    --arg project_version_number "$project_version_number" \
    --arg project_name "$project_name" \
    --arg project_file_url "$project_file_url" \
    --arg project_file_name "$project_file_name" \
    --arg project_url "$project_url" \
    --argjson dependencies "$dependency_json" \
    '{
      id: $project_id,
      version_number: $project_version_number,
      name: $project_name,
      fileUrl: $project_file_url,
      fileName: $project_file_name,
      url: $project_url,
      dependencies: $dependencies
    }')

  PROJECTS_RESOLVED["$project_id"]="$project_node"
  unset "PROJECTS_IN_PROGRESS[$project_id]"

  echo "$project_node"
}


# Resolve a list of projects and its dependencies into a JSON tree.
# 
# Arguments:
#   $1 - Minecraft version
#   $2 - List of projects
#
# Returns:
#   JSON object array representing the projects and their dependencies.
resolve_projects() {
  local minecraft_version="$1"
  local downloads_list_json="$2"

  local -a projects=()

  # Resolve all root nodes without dependencies
  while IFS= read -r project; do
    local project_id
    project_id=$(echo "$project" | jq -r '.id')

    local project_version
    project_version=$(echo "$project" | jq -r '.version // empty')

    # We don''t care about the output, this is just to resolve all root projects
    _resolve_project "$minecraft_version" "$project_id" "$project_version" "none" &>/dev/null

  done < <(echo "$downloads_list_json" | jq -c '.[]')

  # Resolve all root nodes with dependencies
  while IFS= read -r project; do
    local project_id
    project_id=$(echo "$project" | jq -r '.id')

    local project_version
    project_version=$(echo "$project" | jq -r '.version // empty')

    local resolve_dependencies
    resolve_dependencies=$(echo "$project" | jq -r '.downloadDependencies // "required"')

    local project
    project=$(_resolve_project "$minecraft_version" "$project_id" "$project_version" "$resolve_dependencies")

    [[ "$project" == "null" ]] && continue
    
    projects+=("$project")

  done < <(echo "$downloads_list_json" | jq -c '.[]')

  if (( ${#projects[@]} == 0 )); then
    echo "[]"
  else
    echo "${projects[@]}" | jq -s '.'
  fi
}
