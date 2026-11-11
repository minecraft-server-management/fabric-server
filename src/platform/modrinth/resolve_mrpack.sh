import '../../logging/console_log.sh'
import './get_project_slug.sh'
import './api_get.sh'


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
    local raw_url
    raw_url=$(echo "$entry" | jq -r '.downloads[0]')

    local project_id
    project_id=$(get_project_slug "$(echo "$raw_url" | sed -n 's|.*/data/\([^/]\{8\}\)/versions/.*|\1|p')")

    local project_info
    project_info=$(api_get "/project/${project_id}")

    local project_name
    project_name=$(echo "$project_info" | jq -r '.title')

    local project_version_id
    project_version_id=$(echo "$raw_url" | sed -n 's|.*/versions/\([^/]\{8\}\)/.*|\1|p')

    local project_version
    project_version=$(api_get "/version/${project_version_id}")

    local project_version_number
    project_version_number=$(echo "$project_version" | jq -r '.version_number')

    local project_file_url
    project_file_url=$(echo "$project_version" | jq -r '.files[0].url')
    
    local project_file_name
    project_file_name=$(echo "$project_version" | jq -r '.files[0].filename')

    local project_url
    project_url="https://modrinth.com/project/${project_id}/version/${project_version_number}"

    jq -cn \
      --arg project_id "$project_id" \
      --arg project_version_number "$project_version_number" \
      --arg project_name "$project_name" \
      --arg project_file_url "$project_file_url" \
      --arg project_file_name "$project_file_name" \
      --arg project_url "$project_url" \
      '{
        id: $project_id,
        version_number: $project_version_number,
        name: $project_name,
        fileUrl: $project_file_url,
        fileName: $project_file_name,
        url: $project_url,
        dependencies: []
      }'

  done | jq -s '.'
}
