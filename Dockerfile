# syntax=docker/dockerfile:1

# ╔═════════════════════════════════════════════════════╗
# ║                       SETUP                         ║
# ╚═════════════════════════════════════════════════════╝
# GLOBAL
ARG APP_UID=1000 \
    APP_GID=1000

# :: FOREIGN IMAGES
FROM 11notes/distroless AS distroless
FROM 11notes/util AS util
FROM litestream/litestream:0.5.9 AS litestream
FROM 11notes/pocket-id:2.2.0 AS pocket-id

# :: FILE SYSTEM
FROM alpine AS file-system
ARG APP_ROOT=/usr/local \
    POCKET_ID_BIN=/usr/local/bin/pocket-id \
    LITESTREAM_BIN=/usr/local/bin/litestream
COPY --from=util / /
COPY --from=pocket-id /usr/local/bin/pocket-id ${POCKET_ID_BIN}
COPY --from=litestream /usr/local/bin/litestream ${LITESTREAM_BIN}
RUN set -ex; \
    eleven mkdir /distroless${APP_ROOT}/var/{data,uploads,keys,geolite}; \
    eleven mkdir /distroless/etc; \
    eleven distroless ${POCKET_ID_BIN}; \
    eleven distroless ${LITESTREAM_BIN};

# ╔═════════════════════════════════════════════════════╗
# ║                       IMAGE                         ║
# ╚═════════════════════════════════════════════════════╝
# :: HEADER
FROM scratch

# :: default arguments
ARG TARGETPLATFORM \
    TARGETOS \
    TARGETARCH \
    TARGETVARIANT \
    APP_IMAGE \
    APP_NAME \
    APP_VERSION \
    APP_ROOT=/usr/local \
    APP_UID \
    APP_GID \
    APP_NO_CACHE

# :: default environment
ENV APP_IMAGE=${APP_IMAGE} \
    APP_NAME=${APP_NAME} \
    APP_VERSION=${APP_VERSION} \
    APP_ROOT=${APP_ROOT}

# :: app specific environment
ENV APP_ENV=production \
    ANALYTICS_DISABLED=true \
    UPLOAD_PATH=${APP_ROOT}/var/uploads \
    KEYS_PATH=${APP_ROOT}/var/keys \
    GEOLITE_DB_PATH=${APP_ROOT}/var/geolite;

# :: multi-stage
COPY --from=distroless / /
COPY --from=file-system --chown=${APP_UID}:${APP_GID} /distroless/ /
COPY --chown=${APP_UID}:${APP_GID} etc/litestream.yml /etc/litestream.yml

# :: PERSISTENT DATA
VOLUME ["${APP_ROOT}/var"]

EXPOSE 1411

# :: HEALTH
HEALTHCHECK --interval=5s --timeout=2s --start-interval=5s \
    CMD ["/usr/local/bin/pocket-id", "healthcheck"]

# :: EXECUTE
USER ${APP_UID}:${APP_GID}

ENTRYPOINT ["/usr/local/bin/litestream"]
CMD ["replicate"]
