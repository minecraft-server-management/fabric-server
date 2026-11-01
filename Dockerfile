FROM eclipse-temurin:25-jre-alpine

RUN apk add --no-cache \
  bash \
  curl \
  jq \
  # unzip \
  # coreutils \
  ca-certificates \
  netcat-openbsd

# Internal
ENV BASH_ENV=/app/bootstrap.sh

# Extrernal
ENV EULA=false
ENV MEMORY=4G
ENV MINECRAFT_VERSION=latest-release
ENV FABRIC_LOADER_VERSION=latest-stable
ENV FABRIC_INSTALLER_VERSION=latest-stable

WORKDIR /data

COPY --chmod=755 ./src/ /app/

RUN ln -s /app/console.sh /usr/local/bin/console

RUN mkdir -p /data \
  && chown -R 1000:1000 /data

VOLUME ["/data"]
VOLUME ["/config"]
VOLUME ["/mods"]

EXPOSE 25565/tcp

HEALTHCHECK \
  --interval=30s \
  --timeout=5s \
  --start-period=120s \
  --retries=3 \
  CMD ["/app/healthcheck.sh"]

STOPSIGNAL SIGTERM

ENTRYPOINT ["/app/entrypoint.sh"]
