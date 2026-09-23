# syntax=docker/dockerfile:1.26
# Towonel does not publish a standalone release binary like Newt (fosrl/newt),
# only Docker images. We extract the binary via a multi-stage build from the
# upstream image instead of downloading a checksummed release asset.
#
# The upstream image links towonel-agent against glibc (cargo-zigbuild
# targets *-unknown-linux-gnu, final stage is gcr.io/distroless/cc-debian12),
# so this add-on runs on the glibc-based hassio-addons/debian-base rather
# than the musl-based Alpine hassio-addons/base — the binary would not run
# there.
ARG TOWONEL_VERSION=1.7.1
FROM codeberg.org/towonel/towonel-agent:${TOWONEL_VERSION} AS upstream

ARG BUILD_FROM
FROM ${BUILD_FROM}

ARG TOWONEL_VERSION
ENV TOWONEL_VERSION=${TOWONEL_VERSION}
ENV HEALTH_URL="http://127.0.0.1:9090/healthz"

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash jq curl \
    && rm -rf /var/lib/apt/lists/*

# Confirmed against the upstream Dockerfile: the final stage copies the
# binary to exactly this path.
COPY --from=upstream /usr/local/bin/towonel-agent /usr/bin/towonel-agent

COPY run.sh /run.sh
RUN chmod a+x /run.sh /usr/bin/towonel-agent

# towonel-agent has no self-managed health file like Newt; it exposes
# GET /healthz on 127.0.0.1:9090 instead, so the healthcheck curls it
# rather than checking for a file.
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=30s \
  CMD curl -fsS "$HEALTH_URL" || exit 1

ENTRYPOINT ["/run.sh"]
