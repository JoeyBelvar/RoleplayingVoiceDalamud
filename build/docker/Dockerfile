FROM mcr.microsoft.com/dotnet/sdk:10.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip zip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
