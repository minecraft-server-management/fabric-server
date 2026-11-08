FROM eclipse-temurin:25-jre-alpine AS runtime

SHELL ["/bin/sh", "-e", "-u", "-o", "pipefail", "-c"]

RUN apk add --no-cache \
  bash \
  curl \
  jq \
  unzip \
  # coreutils \
  ca-certificates \
  netcat-openbsd

# Internal
ENV BASH_ENV=/app/globals.sh
ENV CONSOLE_DEBUG=true

# Extrernal
ENV EULA=false
ENV MEMORY=4G
ENV MINECRAFT_VERSION=latest-release
ENV FABRIC_LOADER_VERSION=latest-stable
ENV FABRIC_INSTALLER_VERSION=latest-stable

WORKDIR /data

RUN install -d /data -o 1000 -g 1000

COPY --chmod=755 ./src/ /app/

RUN ln -s /app/console.sh /usr/local/bin/console

VOLUME ["/data"]
VOLUME ["/config"]
VOLUME ["/mods"]
VOLUME ["/packs"]

EXPOSE 25565/tcp

HEALTHCHECK \
  --interval=30s \
  --timeout=5s \
  --start-period=120s \
  --retries=3 \
  CMD ["/app/container/health_check.sh"]

STOPSIGNAL SIGTERM

ENTRYPOINT ["/app/main.sh"]
