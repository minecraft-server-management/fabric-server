#!/usr/bin/env bash
#
# remove_old_mods.sh <mods.json>
#
# Removes old mods based on the mods.json config file
#
# Usage:
#   remove_old_mods.sh <mods.json>

set -euo pipefail

import "./logging.sh"

MODS_DIR="/data/mods"

main() {
  [[ $# -eq 1 ]] ||
    die "Usage: $0 <mods.json>"

  local config_file="$1"

  require_command "jq"

  if [[ ! -f "$config_file" ]]; then
    console_error "Config file not found: ${config_file}" >&2
    exit 1
  fi

  REMOVE_OLD="$(
    jq -r '.removeOld // false' "${config_file}"
  )"

  if [[ "${REMOVE_OLD}" != "true" && "${REMOVE_OLD}" != "false" ]]; then
    console_error "Invalid value for 'removeOld': ${REMOVE_OLD}" >&2
    exit 1
  fi

  if [[ "${REMOVE_OLD}" == "true" ]]; then
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
