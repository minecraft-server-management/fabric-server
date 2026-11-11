import '../logging/console_log.sh'
import '../logging/console_link.sh'


_print_projects_tree() {
  local items="$1"
  local prefix="${2:-}"

  local TREE_COLOR="\x1b[38;5;240m"
  local TREE_COLOR_RESET="\x1b[0m"

  local TREE_BRANCH="$TREE_COLOR|- $TREE_COLOR_RESET"
  local TREE_END="$TREE_COLOR\`- $TREE_COLOR_RESET"
  local TREE_BRIDGE="$TREE_COLOR|  $TREE_COLOR_RESET"
  local TREE_BLANK="   "

  local count
  count=$(jq 'length' <<< "$items")

  local index=0

  while IFS= read -r item; do

    ((index+=1))

    local is_last=false
    [[ "$index" -eq "$count" ]] && is_last=true

    local connector="$TREE_BRANCH"
    [[ "$is_last" == "true" ]] && connector="$TREE_END"

    local name
    name=$(jq -r '.name' <<< "$item")

    local url
    url=$(jq -r '.url' <<< "$item")

    local id
    id=$(jq -r '.id' <<< "$item")

    local version_number
    version_number=$(jq -r '.version_number' <<< "$item")

    local link="\x1b]8;;${url}\x1b\\\\${name} [${id}] ${version_number}\x1b]8;;\x1b\\\\"

    console_log "${prefix}${connector}" ""
    console_link "${name} [${id}] ${version_number}" "$url"

    local child_prefix="$prefix"

    if [[ "$is_last" == "true" ]]; then
      child_prefix+="$TREE_BLANK"
    else
      child_prefix+="$TREE_BRIDGE"
    fi

    _print_projects_tree "$(jq -c '.dependencies' <<< "$item")" "$child_prefix"

  done < <(jq -c '.[]' <<< "$items")
}

# Prints all the projects in a nice formatted tree.
# 
# Arguments:
#   $1: JSON tree (the output of resolve_projects)
print_projects_tree() {
  local projects_tree_json="$1"

  _print_projects_tree "$projects_tree_json"
}
