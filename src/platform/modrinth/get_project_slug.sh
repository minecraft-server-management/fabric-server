import './api_get.sh'
import '../../die.sh'


# 
get_project_slug() {
  local id="$1"

  api_get "/project/$id" | jq -r '.slug' ||
    die "Unable to resolve project slug for project id: $id"
}
