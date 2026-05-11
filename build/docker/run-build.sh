#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_NAME="${IMAGE_NAME:-roleplayingvoice-build:dotnet10}"
CONFIGURATION="${CONFIGURATION:-Release}"
VERSION="${VERSION:-0.6.0.3}"
NUGET_CACHE="${NUGET_CACHE:-$REPO_ROOT/.cache/nuget}"
DALAMUD_CACHE="${DALAMUD_CACHE:-$REPO_ROOT/.cache/dalamud}"

mkdir -p "$NUGET_CACHE" "$DALAMUD_CACHE" "$REPO_ROOT/artifacts"

docker build -t "$IMAGE_NAME" "$REPO_ROOT/build/docker"
docker run --rm \
  -e "CONFIGURATION=$CONFIGURATION" \
  -e "VERSION=$VERSION" \
  -e "APPDATA=/tmp/appdata" \
  -v "$REPO_ROOT:/workspace" \
  -v "$NUGET_CACHE:/root/.nuget/packages" \
  -v "$DALAMUD_CACHE:/root/.xlcore/dalamud/Hooks/dev" \
  "$IMAGE_NAME" \
  bash /workspace/build/docker/build-plugin.sh
