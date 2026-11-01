
#!/usr/bin/env bash
#
# download.sh
#
# Downloads Fabric mods from Modrinth and resolves required
# dependencies recursively.
#
# Usage:
#   download.sh <minecraft-version> <mods.json>

set -Eeuo pipefail


# Configuration
MODS_DIR="${MODS_DIR:-/data/mods}"
MODRINTH_API="${MODRINTH_API:-https://api.modrinth.com/v2}"
MODRINTH_LOADER="${MODRINTH_LOADER:-fabric}"

USER_AGENT="ghcr.io/minecraft-server-management/fabric-server"

import "../../logging.sh"


# State
declare -A RESOLVED=()
declare -A RESOLVING=()
declare -A DEPENDENCIES_EXPANDED=()

declare -A PROJECT_NAMES=()
declare -A PROJECT_NAME_CACHE=()
declare -A PROJECT_SLUGS=()
declare -A PROJECT_VERSIONS=()
declare -A PROJECT_VERSION_JSON=()

declare -A PROJECT_FILES=()
declare -A PROJECT_URLS=()
declare -A PROJECT_HASHES=()
declare -A PROJECT_TEMP_FILES=()
declare -A PROJECT_DOWNLOAD=()

declare -A PROJECT_DEPENDENCIES=()
declare -A INSTALLED_FILENAMES=()
declare -A ROOT_DOWNLOAD_DEPENDENCIES=()

declare -a ROOT_PROJECTS=()
declare -a RESOLVED_ORDER=()

TEMP_DIR=""

# Tree connectors
TREE_BRANCH='|-- '
TREE_CONTINUE='|   '
TREE_LAST='\-- '
TREE_BLANK='    '

cleanup() {
  if [[ -n "${TEMP_DIR}" && -d "${TEMP_DIR}" ]]; then
    rm -rf -- "${TEMP_DIR}"
  fi
}

trap cleanup EXIT


# General helpers
die() {
  console_error "$*"
  exit 1
}

api_get() {
  local endpoint="$1"

  curl \
    --fail \
    --silent \
    --show-error \
    --retry 3 \
    --retry-delay 1 \
    --user-agent "${USER_AGENT}" \
    "${MODRINTH_API}${endpoint}"
}

encode_uri() {
  jq -rn --arg value "$1" '$value | @uri'
}

is_compatible() {
  local version_json="$1"
  local minecraft_version="$2"

  jq -e \
    --arg mc "${minecraft_version}" \
    --arg loader "${MODRINTH_LOADER}" \
    '
      (.game_versions | index($mc)) != null
      and
      (.loaders | index($loader)) != null
    ' <<< "${version_json}" >/dev/null
}


# Project metadata
get_project_name() {
  local project_id="$1"
  local encoded_project
  local response
  local project_name

  if [[ -n "${PROJECT_NAME_CACHE[${project_id}]:-}" ]]; then
    printf '%s\n' "${PROJECT_NAME_CACHE[${project_id}]}"
    return 0
  fi

  encoded_project="$(encode_uri "${project_id}")"

  response="$(
    api_get "/project/${encoded_project}"
  )" || return 1

  project_name="$(
    jq -r '.title // .name // .slug // empty' <<< "${response}"
  )"

  [[ -n "${project_name}" ]] || return 1

  PROJECT_NAME_CACHE["${project_id}"]="${project_name}"

  printf '%s\n' "${project_name}"
}

get_project_slug() {
  local project_id="$1"
  local encoded_project
  local response

  encoded_project="$(encode_uri "${project_id}")"

  response="$(
    api_get "/project/${encoded_project}"
  )" || return 1

  jq -r '.slug // empty' <<< "${response}"
}

get_project_version() {
  local project_id="$1"
  local minecraft_version="$2"

  local encoded_project
  local encoded_versions
  local encoded_loaders
  local response

  encoded_project="$(encode_uri "${project_id}")"
  encoded_versions="$(encode_uri "[\"${minecraft_version}\"]")"
  encoded_loaders="$(encode_uri "[\"${MODRINTH_LOADER}\"]")"

  response="$(
    api_get "/project/${encoded_project}/version?game_versions=${encoded_versions}&loaders=${encoded_loaders}"
  )" || return 1

  jq -e '.[0]' <<< "${response}"
}

get_exact_version() {
  local version_id="$1"
  local encoded_version

  encoded_version="$(encode_uri "${version_id}")"

  api_get "/version/${encoded_version}"
}


# Dependency relationships
add_dependency() {
  local parent_id="$1"
  local dependency_id="$2"

  local existing

  [[ -n "${parent_id}" && "${parent_id}" != "root" ]] ||
    return 0

  while IFS= read -r existing; do
    if [[ "${existing}" == "${dependency_id}" ]]; then
      return 1
    fi
  done <<< "${PROJECT_DEPENDENCIES[${parent_id}]:-}"

  PROJECT_DEPENDENCIES["${parent_id}"]+="${dependency_id}"$'\n'

  return 0
}


# Live tree output
print_progress() {
  local prefix="$1"
  local connector="$2"
  local project_name="$3"
  local project_slug="$4"
  local version_id="$5"

  local s

  printf -v s '%s%s%s [%s] (%s)' \
    "${prefix}" \
    "${connector}" \
    "${project_name}" \
    "${project_slug}" \
    "${version_id}"
  
  console_log "$s"
  
}


# Filename conflict detection
check_filename_conflict() {
  local project_id="$1"
  local file_name="$2"
  local file_hash="$3"

  local existing_project
  local existing_hash

  if [[ -z "${INSTALLED_FILENAMES[${file_name}]:-}" ]]; then
    INSTALLED_FILENAMES["${file_name}"]="${project_id}"
    PROJECT_DOWNLOAD["${project_id}"]=1
    return 0
  fi

  existing_project="${INSTALLED_FILENAMES[${file_name}]}"
  existing_hash="${PROJECT_HASHES[${existing_project}]:-}"

  if [[ -n "${file_hash}" &&
        -n "${existing_hash}" &&
        "${file_hash}" == "${existing_hash}" ]]; then

    console_debug "Identical JAR detected: ${file_name}"

    PROJECT_DOWNLOAD["${project_id}"]=0
    return 0
  fi

  die "Filename conflict with different or unverifiable JAR: ${file_name}"
}


# Recursive project resolver
resolve_project() {
  local project_id="${1:-}"
  local project_slug=""
  local parent_id="${2:-root}"
  local download_dependencies="${3:-true}"
  local prefix="${4:-}"
  local connector="${5:-|--}"
  local exact_version_id="${6:-}"

  local version_json=""
  local version_id=""
  local project_name=""

  local file_url=""
  local file_name=""
  local file_hash=""

  local dependency=""
  local dependency_id=""
  local dependency_version=""
  local dependency_type=""

  local child_prefix=""
  local child_connector=""

  local edge_new=true
  local is_new_project=false

  local -a required_dependencies=()

  # Resolve exact version, if specified.
  if [[ -n "${exact_version_id}" ]]; then
    version_json="$(
      get_exact_version "${exact_version_id}"
    )" || die "Could not retrieve version ${exact_version_id}"

    local actual_project_id

    actual_project_id="$(
      jq -r '.project_id // empty' <<< "${version_json}"
    )"

    if [[ -z "${project_id}" ]]; then
      project_id="${actual_project_id}"
    fi

    [[ -n "${project_id}" ]] ||
      die "Could not determine project ID for version ${exact_version_id}"

    [[ "${actual_project_id}" == "${project_id}" ]] ||
      die "Version ${exact_version_id} does not belong to project ${project_id}"

    is_compatible "${version_json}" "${MINECRAFT_VERSION}" ||
      die "Version ${exact_version_id} is incompatible with Minecraft ${MINECRAFT_VERSION} / ${MODRINTH_LOADER}"

    version_id="${exact_version_id}"

  else
    [[ -n "${project_id}" ]] ||
      die "Cannot resolve project without an ID"
  fi

  # Register dependency relationship.
  if [[ "${parent_id}" != "root" ]]; then
    if add_dependency "${parent_id}" "${project_id}"; then
      edge_new=true
    else
      edge_new=false
    fi

    # Do not print the same relationship twice.
    [[ "${edge_new}" == "true" ]] || return 0
  fi

  # Detect circular dependencies.
  if [[ -n "${RESOLVING[${project_id}]:-}" ]]; then
    console_warn "Circular dependency detected: ${project_id}"
    return 0
  fi

  # Already resolved project.
  if [[ -n "${RESOLVED[${project_id}]:-}" ]]; then
    if [[ -n "${exact_version_id}" &&
          "${PROJECT_VERSIONS[${project_id}]}" != "${version_id}" ]]; then
      die "Conflicting exact versions requested for ${project_id}: ${PROJECT_VERSIONS[${project_id}]} and ${version_id}"
    fi

    version_json="${PROJECT_VERSION_JSON[${project_id}]}"
    version_id="${PROJECT_VERSIONS[${project_id}]}"
    project_name="${PROJECT_NAMES[${project_id}]}"
    project_slug="${PROJECT_SLUGS[${project_id}]}"

  else
    # Resolve a new project.
    RESOLVING["${project_id}"]=1
    is_new_project=true

    if [[ -z "${exact_version_id}" ]]; then
      version_json="$(
        get_project_version "${project_id}" "${MINECRAFT_VERSION}"
      )" || die "No compatible version found for ${project_id}"

      is_compatible "${version_json}" "${MINECRAFT_VERSION}" ||
        die "Incompatible version returned for ${project_id}"

      version_id="$(jq -r '.id // empty' <<< "${version_json}")"
    fi

    [[ -n "${version_id}" ]] ||
      die "Could not determine version ID for ${project_id}"

    # Get project name.
    project_name="$(
      get_project_name "${project_id}" 2>/dev/null || true
    )"

    project_slug="$(
      get_project_slug "${project_id}" 2>/dev/null || true
    )"

    [[ -n "${project_slug}" ]] ||
      project_slug="${project_id}"

    if [[ -z "${project_name}" ]]; then
      project_name="$(
        jq -r '.name // empty' <<< "${version_json}"
      )"
    fi

    [[ -n "${project_name}" ]] ||
      project_name="${project_id}"

    # Select primary file or first available file.
    file_url="$(
      jq -r '
        (
          [.files[] | select(.primary == true)][0]
          // .files[0]
        ) | .url // empty
      ' <<< "${version_json}"
    )"

    file_name="$(
      jq -r '
        (
          [.files[] | select(.primary == true)][0]
          // .files[0]
        ) | .filename // empty
      ' <<< "${version_json}"
    )"

    file_hash="$(
      jq -r '
        (
          [.files[] | select(.primary == true)][0]
          // .files[0]
        ) | .hashes.sha1 // empty
      ' <<< "${version_json}"
    )"

    [[ -n "${file_url}" ]] ||
      die "No downloadable file found for ${project_id}"

    [[ -n "${file_name}" ]] ||
      die "No filename found for ${project_id}"

    # Store project information.
    PROJECT_NAMES["${project_id}"]="${project_name}"
    PROJECT_SLUGS["${project_id}"]="${project_slug}"
    PROJECT_VERSIONS["${project_id}"]="${version_id}"
    PROJECT_VERSION_JSON["${project_id}"]="${version_json}"

    PROJECT_FILES["${project_id}"]="${file_name}"
    PROJECT_URLS["${project_id}"]="${file_url}"
    PROJECT_HASHES["${project_id}"]="${file_hash}"

    PROJECT_DOWNLOAD["${project_id}"]=1

    # Check duplicate filenames and hashes.
    check_filename_conflict \
      "${project_id}" \
      "${file_name}" \
      "${file_hash}"

    RESOLVED["${project_id}"]=1
    RESOLVED_ORDER+=("${project_id}")
  fi

  # Print project immediately.
  local version_number
  version_number="$(jq -r '.version_number // "unknown"' <<< "${version_json}")"

  print_progress \
    "${prefix}" \
    "${connector}" \
    "${project_name}" \
    "${project_slug}" \
    "${version_number}"

  # Expand dependencies only once.
  #
  # A project may first be encountered with dependency downloads
  # disabled and later be required by another project.
  if [[ "${download_dependencies}" != "true" ]]; then
    unset 'RESOLVING[$project_id]'
    return 0
  fi

  if [[ -n "${DEPENDENCIES_EXPANDED[${project_id}]:-}" ]]; then
    unset 'RESOLVING[$project_id]'
    return 0
  fi

  RESOLVING["${project_id}"]=1
  DEPENDENCIES_EXPANDED["${project_id}"]=1

  # Collect required dependencies.
  #
  # We collect this one project's dependencies first so that the
  # correct last-child connector is known. We do NOT resolve all
  # projects before printing anything.
  mapfile -t required_dependencies < <(
    jq -c '
      [.dependencies[]? | select(.dependency_type == "required")]
      | .[]
    ' <<< "${version_json}"
  )

  local dependency_count="${#required_dependencies[@]}"
  local dependency_index=0

  # Prefix for children depends on whether this project is the
  # last child of its own parent.
  child_prefix="${prefix}"

  if [[ "${connector}" == "${TREE_LAST}" ]]; then
    child_prefix+="${TREE_BLANK}"
  else
    child_prefix+="${TREE_CONTINUE}"
  fi

  # Resolve dependencies recursively.
  for dependency in "${required_dependencies[@]}"; do
    ((dependency_index += 1))

    dependency_id="$(
      jq -r '.project_id // empty' <<< "${dependency}"
    )"

    dependency_version="$(
      jq -r '.version_id // empty' <<< "${dependency}"
    )"

    dependency_type="$(
      jq -r '.dependency_type // empty' <<< "${dependency}"
    )"

    [[ "${dependency_type}" == "required" ]] || continue

    if [[ -z "${dependency_id}" && -z "${dependency_version}" ]]; then
      die "Dependency of ${project_id} has neither project_id nor version_id"
    fi

    # Select connector based on the actual dependency position.
    child_connector="${TREE_BRANCH}"

    if (( dependency_index == dependency_count )); then
      child_connector="${TREE_LAST}"
    fi

    resolve_project \
      "${dependency_id}" \
      "${project_id}" \
      "${download_dependencies}" \
      "${child_prefix}" \
      "${child_connector}" \
      "${dependency_version}"
  done

  unset 'RESOLVING[$project_id]'
}


# Configuration
load_config() {
  local config_file="$1"

  local mod
  local mod_id
  local platform
  local mod_download
  local existing_root

  local root_index=0
  local root_count=0
  local root_connector=""

  local root_exists

  local -a config_mods=()

  [[ -f "${config_file}" ]] ||
    die "Configuration file not found: ${config_file}"

  jq -e '
    type == "object"
    and (.download | type == "array")
  ' "${config_file}" >/dev/null ||
    die "Invalid mods.json structure: expected an object with a download array"

  GLOBAL_DOWNLOAD_DEPENDENCIES="$(
    jq -r '
      if has("downloadDependencies")
      then .downloadDependencies
      else true
      end
    ' "${config_file}"
  )"

  [[ "${GLOBAL_DOWNLOAD_DEPENDENCIES}" == "true" ||
     "${GLOBAL_DOWNLOAD_DEPENDENCIES}" == "false" ]] ||
    die "downloadDependencies must be a boolean"

  # Read configuration entries.
  mapfile -t config_mods < <(
    jq -c '.download[]' "${config_file}"
  )

  # Collect unique root projects first.
  for mod in "${config_mods[@]}"; do
    platform="$(jq -r '.platform // empty' <<< "${mod}")"
    mod_id="$(jq -r '.id // empty' <<< "${mod}")"

    [[ -n "${mod_id}" ]] ||
      die "Mod entry is missing its id"

    [[ "${platform}" == "modrinth" ]] || continue

    mod_download="$(
      jq -r \
        --argjson global "${GLOBAL_DOWNLOAD_DEPENDENCIES}" \
        '
          if (.downloadDependencies | type) == "boolean"
          then .downloadDependencies
          else $global
          end
        ' <<< "${mod}"
    )"

    [[ "${mod_download}" == "true" ||
       "${mod_download}" == "false" ]] ||
      die "Invalid downloadDependencies value for ${mod_id}"

    root_exists=false

    for existing_root in "${ROOT_PROJECTS[@]}"; do
      if [[ "${existing_root}" == "${mod_id}" ]]; then
        root_exists=true
        break
      fi
    done

    if [[ "${root_exists}" == "false" ]]; then
      ROOT_PROJECTS+=("${mod_id}")
      ROOT_DOWNLOAD_DEPENDENCIES["${mod_id}"]="${mod_download}"
    fi
  done

  root_count="${#ROOT_PROJECTS[@]}"

  [[ "${root_count}" -gt 0 ]] ||
    die "No Modrinth projects found in configuration"

  # Resolve roots one by one.
  console_group "Resolving mods and dependencies"

  for mod_id in "${ROOT_PROJECTS[@]}"; do
    ((root_index += 1))

    root_connector="${TREE_BRANCH}"

    if (( root_index == root_count )); then
      root_connector="${TREE_LAST}"
    fi

    console_debug "Configured Modrinth mod: ${mod_id}"

    resolve_project \
      "${mod_id}" \
      "root" \
      "${ROOT_DOWNLOAD_DEPENDENCIES[${mod_id}]}" \
      "" \
      "${root_connector}"
  done

  console_group
}


# Download and install
download_all() {
  local project_id
  local file_name
  local file_url
  local file_hash
  local temp_file
  local actual_hash

  local index=0

  mkdir -p "${MODS_DIR}"

  TEMP_DIR="$(mktemp -d)"

  console_group "Downloading mods"

  # Download all unique JAR files.
  for project_id in "${RESOLVED_ORDER[@]}"; do
    file_name="${PROJECT_FILES[${project_id}]}"

    if [[ "${PROJECT_DOWNLOAD[${project_id}]:-1}" == "0" ]]; then
      console_debug "Skipping identical JAR: '${file_name}'"
      continue
    fi

    file_url="${PROJECT_URLS[${project_id}]}"
    file_hash="${PROJECT_HASHES[${project_id}]}"

    ((index += 1))

    temp_file="${TEMP_DIR}/${index}.jar"

    console_log "Downloading '${file_name}'"

    curl \
      --fail \
      --silent \
      --show-error \
      --location \
      --retry 3 \
      --retry-delay 1 \
      --user-agent "${USER_AGENT}" \
      --output "${temp_file}" \
      "${file_url}" ||
        die "Download failed: '${file_name}'"

    if [[ -n "${file_hash}" ]]; then
      actual_hash="$(
        sha1sum "${temp_file}" | awk '{print $1}'
      )"

      [[ "${actual_hash}" == "${file_hash}" ]] ||
        die "SHA1 checksum mismatch: '${file_name}'"
    fi

    PROJECT_TEMP_FILES["${project_id}"]="${temp_file}"
  done


  # Install only after every download succeeded.
  for project_id in "${RESOLVED_ORDER[@]}"; do
    file_name="${PROJECT_FILES[${project_id}]}"

    if [[ "${PROJECT_DOWNLOAD[${project_id}]:-1}" == "0" ]]; then
      continue
    fi

    temp_file="${PROJECT_TEMP_FILES[${project_id}]:-}"

    [[ -n "${temp_file}" && -f "${temp_file}" ]] ||
      die "Temporary download not found: '${file_name}'"

    mv -f -- "${temp_file}" "${MODS_DIR}/${file_name}" ||
      die "Could not install: '${file_name}'"
  done

  console_group
}


main() {
  [[ $# -eq 2 ]] ||
    die "Usage: $0 <minecraft-version> <mods.json>"

  MINECRAFT_VERSION="$1"
  local config_file="$2"

  require_command "curl"
  require_command "jq"
  require_command "sha1sum"

  load_config "${config_file}"

  [[ "${#RESOLVED_ORDER[@]}" -gt 0 ]] ||
    die "No mods were resolved"

  console_success "Resolved ${#RESOLVED_ORDER[@]} unique mods"

  download_all

  console_success "All mods downloaded successfully"
}

main "$@"
