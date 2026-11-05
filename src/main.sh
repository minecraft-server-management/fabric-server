#!/usr/bin/env bash
set -Eeuo pipefail

# Imports
import "./logging.sh"

# Configuration
: "${EULA:=false}"
: "${MEMORY:=4G}"
: "${MINECRAFT_VERSION:=latest-release}"
: "${FABRIC_LOADER_VERSION:=latest-stable}"
: "${FABRIC_INSTALLER_VERSION:=latest-stable}"
: "${MODS_CONFIG_FILE:=/config/mods.json}"

DATA_DIR="/data"
MANIFEST_FILE="${DATA_DIR}/.fabric.manifest.json"
CONSOLE_FIFO="/tmp/console.fifo"

FABRIC_META_URL="https://meta.fabricmc.net"
FABRIC_VERSIONS_META_URL="${FABRIC_META_URL}/v2/versions"
FABRIC_INSTALLER_META_URL="${FABRIC_VERSIONS_META_URL}/installer"
FABRIC_LOADER_META_URL="${FABRIC_VERSIONS_META_URL}/loader"
FABRIC_LAUNCHER_FILE="fabric-server-launcher.jar"
FABRIC_LAUNCHER_PATH="./${FABRIC_LAUNCHER_FILE}"
FABRIC_GAME_VERSIONS_URL="${FABRIC_VERSIONS_META_URL}/game"

MODRINTH_API="https://api.modrinth.com/v2"

cd "$DATA_DIR"


die() {
  console_error "$*"
  exit 1
}

# Prepare
console_group "Environment"
console_log "- EULA: $EULA"
console_log "- MEMORY: '$MEMORY'"
console_log "- MINECRAFT_VERSION: '$MINECRAFT_VERSION'"
console_log "- FABRIC_LOADER_VERSION: '$FABRIC_LOADER_VERSION'"
console_log "- FABRIC_INSTALLER_VERSION: '$FABRIC_INSTALLER_VERSION'"
console_log "- MODS_CONFIG_FILE: '$MODS_CONFIG_FILE'"
console_group

if [[ "${EULA,,}" != "true" ]]; then
  die "Accept the Minecraft EULA by setting 'EULA=true'."
fi

if [[ ! "$MEMORY" =~ ^[1-9][0-9]*[KMG]$ ]]; then
  die "Invalid MEMORY='$MEMORY'. Examples: 2G, 4096M, 512K."
fi

# Creating nessasary directories and files
mkdir -p mods config logs
touch server.properties

printf 'eula=true\n' > eula.txt

console_group "Resolving versions"

# Minecraft version
if [[ "$MINECRAFT_VERSION" == "latest" ]]; then
  MINECRAFT_VERSION="$(
    curl -fsSL --retry 3 "$FABRIC_GAME_VERSIONS_URL" |
      jq -er '.[0].version'
  )" || die "Unable to resolve the latest Minecraft version."
elif [[ "$MINECRAFT_VERSION" == "latest-release" ]]; then
  MINECRAFT_VERSION="$(
    curl -fsSL --retry 3 "$FABRIC_GAME_VERSIONS_URL" |
      jq -er '[.[] | select(.stable == true)][0].version'
  )" || die "Unable to resolve the latest release Minecraft version."
elif [[ "$MINECRAFT_VERSION" == "latest-snapshot" ]]; then
  MINECRAFT_VERSION="$(
    curl -fsSL --retry 3 "$FABRIC_GAME_VERSIONS_URL" |
      jq -er '[.[] | select(.stable == false)][0].version'
  )" || die "Unable to resolve the latest snapshot Minecraft version."
else
  curl -fsSL --retry 3 "$FABRIC_GAME_VERSIONS_URL" |
    jq -e --arg game "$MINECRAFT_VERSION" \
      'any(.[]; .version == $game)' >/dev/null ||
      die "  Minecraft version ${MINECRAFT_VERSION} is not available."
fi

console_log "Resolved Minecraft Version: ${MINECRAFT_VERSION}"


# Fabrich loader version
if [[ "$FABRIC_LOADER_VERSION" == "latest" ]]; then
  FABRIC_LOADER_VERSION="$(
    curl -fsSL --retry 3 \
      "${FABRIC_LOADER_META_URL}/${MINECRAFT_VERSION}" |
      jq -er '.[0].loader.version'
  )" || die "Unable to resolve the latest Fabric Loader version for Minecraft ${MINECRAFT_VERSION}."

elif [[ "$FABRIC_LOADER_VERSION" == "latest-stable" ]]; then
  FABRIC_LOADER_VERSION="$(
    curl -fsSL --retry 3 \
      "${FABRIC_LOADER_META_URL}/${MINECRAFT_VERSION}" |
      jq -er '[.[] | select(.loader.stable == true)][0].loader.version'
  )" || die "Unable to resolve the latest stable Fabric Loader version for Minecraft ${MINECRAFT_VERSION}."

elif [[ "$FABRIC_LOADER_VERSION" == "latest-unstable" ]]; then
  FABRIC_LOADER_VERSION="$(
    curl -fsSL --retry 3 \
      "${FABRIC_LOADER_META_URL}/${MINECRAFT_VERSION}" |
      jq -er '[.[] | select(.loader.stable == false)][0].loader.version'
  )" || die "Unable to resolve the latest unstable Fabric Loader version for Minecraft ${MINECRAFT_VERSION}."

else
  curl -fsSL --retry 3 \
    "${FABRIC_LOADER_META_URL}/${MINECRAFT_VERSION}" |
    jq -e --arg loader "$FABRIC_LOADER_VERSION" \
      'any(.[]; .loader.version == $loader)' >/dev/null ||
      die "Fabric Loader version ${FABRIC_LOADER_VERSION} is not available for Minecraft ${MINECRAFT_VERSION}."
fi

console_log "Resolved Fabric Loader version: ${FABRIC_LOADER_VERSION}"


# Fabric installer version
if [[ "$FABRIC_INSTALLER_VERSION" == "latest" ]]; then
  FABRIC_INSTALLER_VERSION="$(
    curl -fsSL --retry 3 "$FABRIC_INSTALLER_META_URL" |
      jq -er '.[0].version'
  )" || die "Unable to resolve the latest Fabric Installer version."

elif [[ "$FABRIC_INSTALLER_VERSION" == "latest-stable" ]]; then
  FABRIC_INSTALLER_VERSION="$(
    curl -fsSL --retry 3 "$FABRIC_INSTALLER_META_URL" |
      jq -er '[.[] | select(.stable == true)][0].version'
  )" || die "Unable to resolve the latest Fabric Installer version."

elif [[ "$FABRIC_INSTALLER_VERSION" == "latest-unstable" ]]; then
  FABRIC_INSTALLER_VERSION="$(
    curl -fsSL --retry 3 "$FABRIC_INSTALLER_META_URL" |
      jq -er '[.[] | select(.stable == false)][0].version'
  )" || die "Unable to resolve the latest Fabric Installer version."

else
  curl -fsSL --retry 3 "$FABRIC_INSTALLER_META_URL" |
    jq -e --arg installer "$FABRIC_INSTALLER_VERSION" \
      'any(.[]; .version == $installer)' >/dev/null ||
      die "Fabric Installer version ${FABRIC_INSTALLER_VERSION} is not available."
fi

console_log "Resolved Fabric Installer version: ${FABRIC_INSTALLER_VERSION}"

console_group


# Manifest
console_group "Prepare manifest"

FABRIC_LAUNCHER_URL="${FABRIC_LOADER_META_URL}/${MINECRAFT_VERSION}/${FABRIC_LOADER_VERSION}/${FABRIC_INSTALLER_VERSION}/server/jar"

CURRENT_MANIFEST="$(
  jq -n \
    --arg launcher "$FABRIC_LAUNCHER_PATH" \
    --arg file "$FABRIC_LAUNCHER_FILE" \
    --arg game "$MINECRAFT_VERSION" \
    --arg loader "$FABRIC_LOADER_VERSION" \
    --arg installer "$FABRIC_INSTALLER_VERSION" \
    '{
      files: [$file],
      launcherPath: $launcher,
      version: {
        game: $game,
        loader: $loader,
        installer: $installer
      }
    }'
)" || die "Unable to generate current manifest."


# Compare current configuration with saved manifest
MANIFEST_MATCH=false

if [[ -s "$MANIFEST_FILE" ]] && [[ -s "$FABRIC_LAUNCHER_FILE" ]] &&
  jq -e --argjson current "$CURRENT_MANIFEST" '
    .files == $current.files and
    .launcherPath == $current.launcherPath and
    .version == $current.version
  ' "$MANIFEST_FILE" >/dev/null 2>&1; then
  MANIFEST_MATCH=true
fi


# Download launcher and update manifest if needed
if [[ "$MANIFEST_MATCH" == true ]]; then
  console_log "Fabric manifest matches the requested versions."
  console_log "Reusing launcher: '$FABRIC_LAUNCHER_PATH'"
else
  console_log "Fabric installation is missing or out of date."

  FABRIC_LAUNCHER_FILE_TMP="${FABRIC_LAUNCHER_FILE}.tmp"

  curl -fLsS --retry 3 \
    "$FABRIC_LAUNCHER_URL" \
    -o "$FABRIC_LAUNCHER_FILE_TMP" ||
    {
      rm "$FABRIC_LAUNCHER_FILE_TMP"
      die "Unable to download Fabric server launcher."
    }

  [[ -s "$FABRIC_LAUNCHER_FILE_TMP" ]] ||
    {
      rm "$FABRIC_LAUNCHER_FILE_TMP"
      die "Downloaded Fabric server launcher is empty."
    }
  
  mv -f "$FABRIC_LAUNCHER_FILE_TMP" "$FABRIC_LAUNCHER_FILE"

  [[ -s "$FABRIC_LAUNCHER_FILE" ]] ||
    die "Fabric Launcher does not exist: ${FABRIC_LAUNCHER_PATH}"
  
  console_log "Downloading Fabric server launcher"

  # Add timestamp and save the updated manifest
  UPDATED_MANIFEST="$(
    jq --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
      '. + {timestamp: $timestamp}' <<< "$CURRENT_MANIFEST"
  )" || die "Unable to update manifest timestamp."

  printf '%s\n' "$UPDATED_MANIFEST" > "$MANIFEST_FILE" ||
    die "Unable to write Fabric manifest."

  console_log "Updated Fabric manifest"
fi

console_group

# Remove old mods
/app/remove_old_mods.sh "$MODS_CONFIG_FILE"


# Resolve and download mods
console_info "Platform: Modrinth"
/app/platform/modrinth/download.sh 1.21.1 "$MODS_CONFIG_FILE"


# Copy mods
console_info "Copying files from /mods to /data/mods"
/app/copy_mods_directory.sh


# Start server
console_info "Starting server"

rm -f "$CONSOLE_FIFO"
mkfifo "$CONSOLE_FIFO"

exec 3<>"$CONSOLE_FIFO"

exec java \
  "-Xms${MEMORY}" \
  "-Xmx${MEMORY}" \
  -jar "${FABRIC_LAUNCHER_FILE}" \
  nogui \
  < "$CONSOLE_FIFO"
