FROM alpine:3.18

LABEL name="qbittorrent-gluetun-port-update"
LABEL maintainer="PopeRigby <poperigby@mailbox.org>"
LABEL org.opencontainers.image.source="https://github.com/poperigby/qbittorrent-gluetun-port-update"
LABEL org.opencontainers.image.description="Image for updating qBitorrent port based on Gluetun"

RUN apk add --no-cache curl && \
    apk add --no-cache jq

ENV QBITTORRENT_WEBUI_HOST=127.0.0.1 \
    QBITTORRENT_WEBUI_PORT=8080 \
    QBITTORRENT_WEBUI_USERNAME=admin \
    QBITTORRENT_WEBUI_PASSWORD=adminadmin \
    GLUETUN_CONTROL_HOST=127.0.0.1\
    GLUETUN_CONTROL_PORT=8000 \
    INITIAL_DELAY_SEC=10 \
    CHECK_INTERVAL_SEC=60 \
    ERROR_INTERVAL_SEC=5 \
    ERROR_INTERVAL_COUNT=5

COPY port-update.sh /port-update.sh

CMD ["/bin/sh", "/port-update.sh"]

