ARG RESILIO_BASE_PLATFORM=linux/amd64
FROM --platform=${RESILIO_BASE_PLATFORM} resilio/sync:latest

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY bootstrap-resilio.sh /usr/local/bin/artemis-resilio-bootstrap

RUN chmod +x /usr/local/bin/artemis-resilio-bootstrap

ENTRYPOINT ["/usr/local/bin/artemis-resilio-bootstrap"]
CMD ["--config", "/mnt/sync/sync.conf"]
