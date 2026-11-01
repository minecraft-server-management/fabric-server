#!/usr/bin/env bash
#
# copy_mods_directory.sh
#
# Copies all files from /mods to /data/mods
#
# Usage:
#   copy_mods_directory.sh

set -Eeuo pipefail

SOURCE_DIR="/mods"
TARGET_DIR="/data/mods"

main() {
  mkdir -p "${TARGET_DIR}"

  if [ -d "${SOURCE_DIR}" ]; then
    cp -a "${SOURCE_DIR}/." "${TARGET_DIR}/"
    echo "Mods successfully copied."
  else
    echo "Source directory ${SOURCE_DIR} does not exist."
    exit 1
  fi
}

main "$@"
