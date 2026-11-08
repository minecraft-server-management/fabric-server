import "./api_get.sh"

# 
get_project_slug() {
  local id="$1"

  api_get "/project/$id" | jq -r '.slug'
}
