FROM alpine:3.20

RUN apk add --no-cache \
    bash \
    postgresql16-client \
    curl \
    jq \
    tzdata \
    busybox-suid

RUN curl -L https://dl.min.io/client/mc/release/linux-amd64/mc -o /usr/local/bin/mc \
    && chmod +x /usr/local/bin/mc

WORKDIR /scripts

COPY entrypoint.sh /scripts/entrypoint.sh
COPY run_backup.sh /scripts/run_backup.sh
COPY setup-minio.sh /scripts/setup-minio.sh

RUN chmod +x /scripts/*.sh

ENTRYPOINT ["/scripts/entrypoint.sh"]