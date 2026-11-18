import './api_get.sh'
import '../../logging/console_warn.sh'

# Checks if the given id is a valid modrinth project id
#
# Arguments:
#   $1 - ID of the project
is_valid_project_id() {
  local id="$1"

  if api_get "/project/$id" > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}
