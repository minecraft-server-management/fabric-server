import '../../logging/console_log.sh'
import '../../logging/console_info.sh'
import '../../logging/console_error.sh'
import '../../logging/console_success.sh'
import './resolve_projects.sh'
import './get_project_ids.sh'
import '../print_projects_tree.sh'


# Configuration
MODS_DIR="${MODS_DIR:-/data/mods}"


# General helpers
die() {
  console_error "$*"
  exit 1
}


main() {
  [[ $# -eq 2 ]] ||
    die "Usage: $0 <minecraft_version> <downloads.json>"

  local minecraft_version="$1"
  local downloads_config_file="$2"
  local projects_tree_json
  local projects_list_json

  download_list_json="$(
    jq -r '.download // []' "${downloads_config_file}"
  )"

  console_log 'Resolving projects ... (this might take a while)'

  projects_tree_json="$(resolve_projects "$minecraft_version" "$download_list_json")" ||
    die "Failed to resolve projects and dependencies"

  local -a project_ids
  mapfile -t project_ids < <(get_project_ids "$projects_tree_json") ||
    die "Failed to retrieve project IDs"
  
  print_projects_tree "$projects_tree_json"

  console_log ""
  console_log "Resolved ${#project_ids[@]} unique projects"  

  sleep 5


  console_success "All mods downloaded successfully"
}

main "$@"
