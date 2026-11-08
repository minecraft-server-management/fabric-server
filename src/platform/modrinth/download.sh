import '../../logging/console_log.sh'
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

  projects_tree_json="$(resolve_projects "$minecraft_version" "$download_list_json")" ||
    die "Failed to resolve projects and dependencies"

  echo "$projects_tree_json" | jq .

  print_projects_tree "$projects_tree_json"

  sleep 5

  # projects_list_json=$(get_project_ids "$projects_tree_json") ||
  #   die "Failed to retrieve project IDs"

  console_success "All mods downloaded successfully"
}

main "$@"
