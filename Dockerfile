FROM eclipse-temurin:25-jre-alpine

RUN apk add --no-cache \
  bash \
  curl \
  jq \
  ca-certificates \
  netcat-openbsd

ENV MEMORY=4G
ENV MINECRAFT_VERSION=latest-release
ENV FABRIC_LOADER_VERSION=latest-stable
ENV FABRIC_INSTALLER_VERSION=latest-stable
ENV EULA=false
ENV SERVER_PORT=25565

WORKDIR /data

COPY ./src/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY ./src/healthcheck.sh /usr/local/bin/healthcheck.sh

RUN chmod +x \
  /usr/local/bin/entrypoint.sh \
  /usr/local/bin/healthcheck.sh

RUN mkdir -p /data \
  && chown -R 1000:1000 /data

VOLUME ["/data"]

EXPOSE 25565/tcp

HEALTHCHECK \
  --interval=30s \
  --timeout=5s \
  --start-period=120s \
  --retries=3 \
  CMD ["/usr/local/bin/healthcheck.sh"]

STOPSIGNAL SIGTERM

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
