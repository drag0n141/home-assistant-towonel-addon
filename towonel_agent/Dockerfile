# Towonel veröffentlicht kein eigenständiges Release-Binary wie Newt (fosrl/newt),
# nur Docker-Images. Wir extrahieren das Binary daher per Multi-Stage-Build aus
# dem Upstream-Image, statt es wie im Newt-Add-on per Checksum herunterzuladen.
ARG TOWONEL_VERSION=1.7.1
FROM codeberg.org/towonel/towonel-agent:${TOWONEL_VERSION} AS upstream

ARG BUILD_FROM
FROM ${BUILD_FROM}

ARG TOWONEL_VERSION
ENV TOWONEL_VERSION=${TOWONEL_VERSION}
ENV HEALTH_URL="http://127.0.0.1:9090/healthz"

RUN apk add --no-cache bash jq curl

# WICHTIG: Pfad vor dem Bauen gegen das tatsächliche Image prüfen, z.B. mit:
#   docker run --rm --entrypoint sh codeberg.org/towonel/towonel-agent:1.7.1 -c 'which towonel-agent'
COPY --from=upstream /usr/local/bin/towonel-agent /usr/bin/towonel-agent

COPY run.sh /run.sh
RUN chmod a+x /run.sh /usr/bin/towonel-agent

# towonel-agent führt keine eigene Health-Datei wie Newt, sondern exponiert
# GET /healthz auf 127.0.0.1:9090 – der Healthcheck prüft daher per curl statt
# per Datei-Existenz.
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=30s \
  CMD curl -fsS "$HEALTH_URL" || exit 1

ENTRYPOINT ["/run.sh"]
