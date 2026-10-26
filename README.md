# Minecraft Fabric Server
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
    image: 'ghcr.io/minecraft-server-management/fabric-server:latest'
    container_name: 'fabric-server'
    restart: unless-stopped

    ports:
      - '25565:25565'

    environment:
      EULA: 'true'
      MEMORY: '4G'
      MINECRAFT_VERSION: '26.2'

    volumes:
      - './data:/data'

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

## Configuration

### Server
The server can be configured using environment variables.

| Variable                   | Default          | Description                                                               |
|----------------------------|------------------|---------------------------------------------------------------------------|
| `EULA`                     | `false`          | Must be set to `true`                                                     |
| `MEMORY`                   | `4G`             | Java heap size, e.g. `2G` or `4096M`                                      |
| `MINECRAFT_VERSION`        | `latest-release` | Minecraft version, or `latest`, `latest-release`, `latest-snapshot`       |
| `FABRIC_LOADER_VERSION`    | `latest-stable`  | Fabric Loader version, or `latest`, `latest-stable`, `latest-unstable`    |
| `FABRIC_INSTALLER_VERSION` | `latest-stable`  | Fabric Installer version, or `latest`, `latest-stable`, `latest-unstable` |

### Ports

The default Minecraft Java Edition port is `25565/TCP`.

You can change the port, by mapping it, like so:

```yaml
ports:
  # ...
  - '25565:25565'
```

### Mods

#### Remote

Mods can be downloaded automatically.

A schema for the `mods.json` can be found in [`schema/mods.v1.schema.json`](./schema/mods.v1.schema.json).

> [!IMPORTANT]
> - **Mod source:** Only Modrinth is currently supported by `mods.json`.
> - **Dependencies:** Dependencies are downloaded automatically by default. You can disable dependency downloads globally or for an individual mod using `downloadDependencies`.
> - **Existing mods:** With `removeOld` set to `true`, the entire mods directory is cleaned before the configured mods are downloaded. This also removes manually installed mods. Set it to `false` if you want to preserve existing files.

To configure this behavior, create a `mods.json` file next to your `compose.yml`:

```json
{
  "$schema": "https://raw.githubusercontent.com/minecraft-server-management/fabric-server/refs/heads/main/schema/mods.v1.schema.json"
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

Mount the configuration file:

```yaml
volumes:
  # ...
  - ./mods.json:/config/mods.json
```

#### Local

The `/mods` mount allows you to provide your own mod files. At the start, all files inside the `/mods` mount are copied to the `/data/mods` directory.

Mount the directory:

```yaml
volumes:
  # ...
  - ./mods:/mods
```

### Data

All server data is stored in `/data`.

Mount the directory:

```yaml
volumes:
  # ...
  - ./data:/data
```

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
docker logs -f fabric-server
```

Note that logs are read-only. Use `docker attach fabric-server` to interact with the Minecraft console.
