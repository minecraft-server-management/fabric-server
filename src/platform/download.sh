import '../logging/console_log.sh'
import '../logging/console_success.sh'
import './get_project_ids.sh'
import './print_projects_tree.sh'


# Configuration
MODS_DIR="${MODS_DIR:-/data/mods}"

# General helpers
die() {
  console_error "$*"
  exit 1
}


download() {
  [[ $# -eq 2 ]] ||
    die "Usage: $0 <minecraft_version> <path/to/downloads.json>"
  
  local minecraft_version="$1"
  local downloads_json_file="$2"

  local projects_tree_json
  projects_tree_json=$(/app/platform/modrinth/main.sh "$minecraft_version" "$downloads_json_file")


  print_projects_tree "$projects_tree_json"

  local -a project_ids
  mapfile -t project_ids < <(get_project_ids "$projects_tree_json") ||
    die "Failed to retrieve project IDs"

  console_log
  console_log "Resolved ${#project_ids[@]} unique projects"

  console_success "All mods downloaded successfully"
}
