import "./logging/console_log.sh"
import "./logging/console_error.sh"


MODS_DIR="/data/mods"

main() {
  [[ $# -eq 1 ]] ||
    die "Usage: $0 <mods.json>"

  local config_file="$1"
  local remove_old

  if [[ ! -f "$config_file" ]]; then
    console_error "Config file not found: ${config_file}" >&2
    exit 1
  fi

  remove_old="$(
    jq -r '.removeOld // false' "${config_file}"
  )"

  if [[ "${remove_old}" != "true" && "${remove_old}" != "false" ]]; then
    console_error "Invalid value for 'removeOld': ${remove_old}" >&2
    exit 1
  fi

  if [[ "${remove_old}" == "true" ]]; then
    if [[ -d "${MODS_DIR}" ]]; then
      find "${MODS_DIR}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
      console_log "Removed all old mods from ${MODS_DIR}"
    else
      mkdir -p "${MODS_DIR}"
      console_log "Created ${MODS_DIR}"
    fi
  fi
}

main "$@"
