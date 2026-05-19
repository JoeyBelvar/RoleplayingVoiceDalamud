ARG RESILIO_BASE_PLATFORM=linux/amd64
ARG DOTNET_BASE_PLATFORM=${RESILIO_BASE_PLATFORM}

FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:7.0 AS relay-shim-build

WORKDIR /src
COPY relay-shim/ArtemisRelayShim.csproj relay-shim/
RUN dotnet restore relay-shim/ArtemisRelayShim.csproj
COPY relay-shim/ relay-shim/
RUN dotnet publish relay-shim/ArtemisRelayShim.csproj \
    --configuration Release \
    --no-restore \
    --output /out

FROM --platform=${DOTNET_BASE_PLATFORM} mcr.microsoft.com/dotnet/runtime:7.0 AS dotnet-runtime

FROM --platform=${RESILIO_BASE_PLATFORM} resilio/sync:latest

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates libicu74 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=dotnet-runtime /usr/share/dotnet /usr/share/dotnet
COPY --from=relay-shim-build /out /opt/artemis/relay-shim
COPY bootstrap-resilio.sh /usr/local/bin/artemis-resilio-bootstrap

RUN chmod +x /usr/local/bin/artemis-resilio-bootstrap

ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH="${PATH}:/usr/share/dotnet"

ENTRYPOINT ["/usr/local/bin/artemis-resilio-bootstrap"]
CMD ["--config", "/mnt/sync/sync.conf"]
