# syntax=docker/dockerfile:1

# global
ARG APP_UID=1000 \
    APP_GID=1000

# foreign images
FROM litestream/litestream:0.5.9 AS litestream
FROM ghcr.io/pocket-id/pocket-id:v2.3.0-distroless AS pocket-id


# header
FROM gcr.io/distroless/static-debian12:nonroot

# default arguments
ARG APP_IMAGE \
    APP_NAME \
    APP_VERSION \
    APP_ROOT=/usr/local \
    APP_UID \
    APP_GID

# default environment
ENV APP_IMAGE=${APP_IMAGE} \
    APP_NAME=${APP_NAME} \
    APP_VERSION=${APP_VERSION} \
    APP_ROOT=${APP_ROOT}

# app specific environment
ENV APP_ENV=production \
    ANALYTICS_DISABLED=true \
    UPLOAD_PATH=${APP_ROOT}/var/uploads \
    KEYS_PATH=${APP_ROOT}/var/keys \
    GEOLITE_DB_PATH=${APP_ROOT}/var/geolite;

# binaries and config
COPY --chown=${APP_UID}:${APP_GID} --from=pocket-id /app/pocket-id /usr/local/bin/pocket-id
COPY --chown=${APP_UID}:${APP_GID} --from=litestream /usr/local/bin/litestream /usr/local/bin/litestream
COPY --chown=${APP_UID}:${APP_GID} etc/litestream.yml /etc/litestream.yml

# pre-create directories with correct ownership
USER ${APP_UID}:${APP_GID}
WORKDIR ${APP_ROOT}/var/data
WORKDIR ${APP_ROOT}/var/uploads
WORKDIR ${APP_ROOT}/var/keys
WORKDIR ${APP_ROOT}/var/geolite
WORKDIR /

# persistent data
VOLUME ["${APP_ROOT}/var"]

EXPOSE 1411

# health
HEALTHCHECK --interval=5s --timeout=2s --start-interval=5s CMD ["/usr/local/bin/pocket-id", "healthcheck"]

ENTRYPOINT ["/usr/local/bin/litestream"]
CMD ["replicate"]
