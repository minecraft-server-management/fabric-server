import '../logging/console_log.sh'
import '../logging/console_success.sh'
import './get_project_ids.sh'
import './print_projects_tree.sh'
import '../die.sh'


# Configuration
MODS_DIR="${MODS_DIR:-/data/mods}"


download() {
  [[ $# -eq 2 ]] ||
    die "Usage: $0 <minecraft_version> <path/to/downloads.json>"
  
  local minecraft_version="$1"
  local downloads_json_file="$2"

  local projects_tree_json_start_time
  projects_tree_json_start_time=$(date +%s%N)

  local projects_tree_json
  projects_tree_json=$(/app/platform/modrinth/main.sh "$minecraft_version" "$downloads_json_file")

  local projects_tree_json_end_time
  projects_tree_json_end_time=$(date +%s%N)
  local projects_tree_json_duration_ms=$(( (projects_tree_json_end_time - projects_tree_json_start_time) / 1000000 ))

  local -a project_ids
  mapfile -t project_ids < <(get_project_ids "$projects_tree_json") ||
    die "Failed to retrieve project IDs"

  console_log "Resolved ${#project_ids[@]} unique projects in ${projects_tree_json_duration_ms}ms"

  print_projects_tree "$projects_tree_json"

  console_log

  console_success "All mods downloaded successfully"
}
