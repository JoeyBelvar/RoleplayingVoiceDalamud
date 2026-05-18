FROM mcr.microsoft.com/dotnet/runtime:7.0

COPY run-relay.sh /usr/local/bin/artemis-run-relay

RUN chmod +x /usr/local/bin/artemis-run-relay

WORKDIR /payload

ENTRYPOINT ["/usr/local/bin/artemis-run-relay"]
