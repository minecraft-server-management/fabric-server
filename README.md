# Fabric Minecraft Server
[![Build and Publish Docker Image](https://github.com/minecraft-server-management/fabric-server/actions/workflows/build_and_push.yml/badge.svg)](https://github.com/minecraft-server-management/fabric-server/actions/workflows/build_and_push.yml)

A Docker-based Minecraft fabricmc server.

## Requirements

- Docker
- Docker Compose

## Quick Start

Create a `compose.yml` file or use the [`compose.yml`](./examples/compose.yml) example:

```yaml
services:
  server:
    image: ghcr.io/minecraft-server-management/fabric-server:latest
    container_name: "fabric-server"
    restart: unless-stopped

    ports:
      - "25565:25565"

    environment:
      EULA: "true"
      MEMORY: "4G"
      MINECRAFT_VERSION: "26.2"

    volumes:
      - ./data:/data

    stdin_open: true
    tty: true
```
> Accept the [Minecraft EULA](https://www.minecraft.net/eula) before starting the server.

Start the server:

```bash
docker compose up -d
```

Attach to the Minecraft console:

```bash
docker attach fabric-server
```

To detach without stopping the server, press <kbd>Ctrl+P</kbd>, then <kbd>Ctrl+Q</kbd>.

## Server Configuration

The server can be configured using environment variables.

| Variable                   | Default          | Description                                                               |
|----------------------------|------------------|---------------------------------------------------------------------------|
| `EULA`                     | `false`          | Must be set to `true`                                                     |
| `MEMORY`                   | `4G`             | Java heap size, e.g. `2G` or `4096M`                                      |
| `MINECRAFT_VERSION`        | `latest-release` | Minecraft version, or `latest`, `latest-release`, `latest-snapshot`       |
| `FABRIC_LOADER_VERSION`    | `latest-stable`  | Fabric Loader version, or `latest`, `latest-stable`, `latest-unstable`    |
| `FABRIC_INSTALLER_VERSION` | `latest-stable`  | Fabric Installer version, or `latest`, `latest-stable`, `latest-unstable` |

## Mod Configuration (`mods.json`)

Mods can be downloaded automatically from Modrinth by mounting a `mods.json` file into the container at `/config/mods.json`.

### Example

Create a `mods.json` file next to your `compose.yml`:

```json
{
  "removeOld": true,
  "downloadDependencies": true,
  "download": [
    {
      "platform": "modrinth",
      "id": "fabric-api"
    },
    {
      "platform": "modrinth",
      "id": "lithium",
      "downloadDependencies": false
    }
  ]
}
```

Mount the configuration file in your `compose.yml`:

```yaml
volumes:
  - ./data:/data
  - ./mods:/mods
  - ./mods.json:/config/mods.json
```

### Configuration Options

| Option                 | Type    | Default | Description                                                                                                                             |
|------------------------|---------|---------|-----------------------------------------------------------------------------------------------------------------------------------------|
| `removeOld`            | Boolean | `true`  | Removes existing files from the entire mods directory before downloading the configured mods. Set to `false` to preserve existing mods. |
| `downloadDependencies` | Boolean | `true`  | Automatically resolves and downloads mod dependencies.                                                                                  |
| `download`             | Array   | `[]`    | List of mods to download from the configured platform.                                                                                  |

Each entry in the `download` array supports the following properties:

| Property               | Type    | Required | Default | Description                                                                   |
|------------------------|---------|----------|---------|-------------------------------------------------------------------------------|
| `platform`             | String  | Yes      | -       | Mod source. Currently, only `modrinth` is supported.                          |
| `id`                   | String  | Yes      | -       | Modrinth project ID or slug, for example `fabric-api`.                        |
| `downloadDependencies` | Boolean | No       | `true`  | Controls automatic dependency resolution for this mod. (Not implemented yet!) |

### Important Notes

- **Mod source:** Only Modrinth is currently supported by `mods.json`.
- **Dependencies:** Dependencies are downloaded automatically by default. You can disable dependency downloads globally or for an individual mod using `downloadDependencies`.
- **Existing mods:** With `removeOld` set to `true`, the entire mods directory is cleaned before the configured mods are downloaded. This can remove manually installed mods as well. Set it to `false` if you want to preserve existing files.
- **Manual mods:** The `/mods` mount allows you to provide your own mod files. Be aware that `removeOld: true` can remove these files during preparation.
- **Schema validation:** The complete JSON Schema is available at [`./schema/mods.v1.schema.json`](./schema/mods.v1.schema.json).

## Data Persistence

All server data is stored in `./data` on the host:

- World files
- Mods and configurations
- Server properties
- Logs

The data directory persists when the container is recreated or the image is updated.

## Updating

Pull the latest image and recreate the container:

```bash
docker compose pull
docker compose up -d
```

Your existing server data remains in `./data`.

To use a specific image version, replace `latest` in the image reference with the desired tag.

## Logs

View server logs:

```bash
docker compose logs -f server
```

Note that logs are read-only. Use `docker attach fabric-server` to interact with the Minecraft console.

## Ports

The default Minecraft Java Edition port is `25565/TCP`.

Make sure the port is accessible through your firewall if players need to connect from outside your network.
