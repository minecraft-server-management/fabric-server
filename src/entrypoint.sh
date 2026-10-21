#!/usr/bin/env bash
set -Eeuo pipefail

# Configuration
: "${EULA:=false}"
: "${MEMORY:=4G}"
: "${MINECRAFT_VERSION:=latest-release}"
: "${FABRIC_LOADER_VERSION:=latest-stable}"
: "${FABRIC_INSTALLER_VERSION:=latest-stable}"

DATA_DIR="/data"
MANIFEST_FILE="${DATA_DIR}/.fabric-manifest.json"
FABRIC_META_URL="https://meta.fabricmc.net"
FABRIC_VERSIONS_META_URL="${FABRIC_META_URL}/v2/versions"
FABRIC_INSTALLER_META_URL="${FABRIC_VERSIONS_META_URL}/installer"
FABRIC_LOADER_META_URL="${FABRIC_VERSIONS_META_URL}/loader"
GAME_VERSIONS_URL="${FABRIC_VERSIONS_META_URL}/game"

cd "$DATA_DIR"

log() {
  printf '[LOG] %s\n' "$*"
}

error() {
  printf '\033[31m[ERROR] %s\033[0m\n' "$*" >&2
}

die() {
  error "$*"
  exit 1
}

if [[ "${EULA,,}" != "true" ]]; then
  die "Accept the Minecraft EULA by setting 'EULA=true'."
fi

if [[ ! "$MEMORY" =~ ^[1-9][0-9]*[KMG]$ ]]; then
  die "Invalid MEMORY='$MEMORY'. Examples: 2G, 4096M, 512K."
fi

mkdir -p mods config logs

printf 'eula=true\n' > eula.txt

log "Resolving Minecraft version ..."

if [[ "$MINECRAFT_VERSION" == "latest" ]]; then
  MINECRAFT_VERSION="$(
    curl -fsSL --retry 3 "$GAME_VERSIONS_URL" |
      jq -er '.[0].version'
  )" || die "Unable to resolve the latest Minecraft version."
elif [[ "$MINECRAFT_VERSION" == "latest-release" ]]; then
  MINECRAFT_VERSION="$(
    curl -fsSL --retry 3 "$GAME_VERSIONS_URL" |
      jq -er '[.[] | select(.stable == true)][0].version'
  )" || die "Unable to resolve the latest release Minecraft version."
elif [[ "$MINECRAFT_VERSION" == "latest-snapshot" ]]; then
  MINECRAFT_VERSION="$(
    curl -fsSL --retry 3 "$GAME_VERSIONS_URL" |
      jq -er '[.[] | select(.stable == false)][0].version'
  )" || die "Unable to resolve the latest snapshot Minecraft version."
else
  curl -fsSL --retry 3 "$GAME_VERSIONS_URL" |
    jq -e --arg game "$MINECRAFT_VERSION" \
      'any(.[]; .version == $game)' >/dev/null ||
      die "Minecraft version ${MINECRAFT_VERSION} is not available."
fi

log "Resolving Fabric Loader version for Minecraft ${MINECRAFT_VERSION} ..."

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

# Resolve Fabric Installer version
log "Resolving Fabric Installer version ..."

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

log "Minecraft: ${MINECRAFT_VERSION}"
log "Fabric Loader: ${FABRIC_LOADER_VERSION}"
log "Fabric Installer: ${FABRIC_INSTALLER_VERSION}"

# Prepare current manifest information
FABRIC_LAUNCHER_FILE="fabric-server-launcher.jar"
FABRIC_LAUNCHER_PATH="./${FABRIC_LAUNCHER_FILE}"
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
  log "Fabric manifest matches the requested versions."
  log "Reusing launcher: ${FABRIC_LAUNCHER_PATH}"
else
  log "Fabric installation is missing or out of date."
  log "Downloading Fabric server launcher ..."

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

  log "Updating Fabric manifest ..."

  # Add timestamp and save the updated manifest
  UPDATED_MANIFEST="$(
    jq --arg timestamp "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
      '. + {timestamp: $timestamp}' <<< "$CURRENT_MANIFEST"
  )" || die "Unable to update manifest timestamp."

  printf '%s\n' "$UPDATED_MANIFEST" > "$MANIFEST_FILE" ||
    die "Unable to write Fabric manifest."

  log "Updated Fabric manifest."
fi


# Start server
log "Starting Fabric server ..."
log "Launcher: ${FABRIC_LAUNCHER_PATH}"
log "Java Heap: ${MEMORY}"

exec java \
  "-Xms${MEMORY}" \
  "-Xmx${MEMORY}" \
  -jar "${FABRIC_LAUNCHER_FILE}" \
  nogui
