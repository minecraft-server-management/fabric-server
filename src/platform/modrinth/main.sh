import '../../logging/console_log.sh'
import '../../logging/console_info.sh'
import '../../logging/console_error.sh'
import './resolve_projects.sh'


# General helpers
die() {
  console_error "$*"
  exit 1
}

# Resolves all downloads into a project tree
#
# Arguments:
#   $1: Minecraft version
#   $2: Path to downloads.json file
#
# Returns:
#   Project tree as a json structure.
main() {
  [[ $# -eq 2 ]] ||
    die "Usage: $0 <minecraft_version> <path/to/downloads.json>"

  local minecraft_version="$1"
  local downloads_json_file="$2"

  console_info "Platform: Modrinth"

  download_list_json="$(jq -r '.download // []' "${downloads_json_file}")"

  console_log 'Resolving projects ... (this might take a while)'

  resolve_projects "$minecraft_version" "$download_list_json" ||
    die "Failed to resolve projects and dependencies"
}

main "$@"
