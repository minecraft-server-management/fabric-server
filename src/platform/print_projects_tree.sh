_print_projects_tree() {
  local items="$1"
  local prefix="${2:-}"

  local count
  count=$(jq 'length' <<< "$items")

  local index=0

  while IFS= read -r item; do

    ((index++))

    local is_last=false
    [[ "$index" -eq "$count" ]] && is_last=true

    local connector="\x1b[38;5;245m├╴\x1b[0m"
    [[ "$is_last" == "true" ]] && connector="\x1b[38;5;245m╰╴\x1b[0m"

    local name
    name=$(jq -r '.name' <<< "$item")

    local url
    url=$(jq -r '.url' <<< "$item")

    local id
    id=$(jq -r '.id' <<< "$item")

    local version
    version=$(jq -r '.version' <<< "$item")

    # local link="\x1b]8;;${url}\x1b\\\\${name} [${id}] ${version}\x1b]8;;\x1b\\\\"

    # echo -e "${prefix}${connector}${link}"

    # local child_prefix="$prefix"

    # if [[ "$is_last" == "true" ]]; then
    #   child_prefix+="  "
    # else
    #   child_prefix+="\x1b[38;5;245m│ \x1b[0m"
    # fi

    _print_projects_tree "$(jq -c '.dependencies' <<< "$item")" # "$child_prefix"

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
