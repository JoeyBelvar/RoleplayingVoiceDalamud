#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${CONFIGURATION:-Release}"
VERSION="${VERSION:-0.6.0.3}"
APPDATA="${APPDATA:-/tmp/appdata}"
DALAMUD_WINDOWS_DIR="$APPDATA/XIVLauncher/addon/Hooks/dev"
DALAMUD_LINUX_DIR="/root/.xlcore/dalamud/Hooks/dev"
ARTIFACT_DIR="/workspace/artifacts"
OUTPUT_DIR="/workspace/ArtemisRoleplayingKit/bin/$CONFIGURATION"

mkdir -p "$DALAMUD_WINDOWS_DIR" "$DALAMUD_LINUX_DIR" "$ARTIFACT_DIR"

if [ ! -f "$DALAMUD_LINUX_DIR/Dalamud.dll" ]; then
  echo "Downloading Dalamud dev bundle..."
  curl -fsSL "https://goatcorp.github.io/dalamud-distrib/stg/latest.zip" -o /tmp/dalamud-latest.zip
  unzip -q -o /tmp/dalamud-latest.zip -d "$DALAMUD_LINUX_DIR"
  cp -a "$DALAMUD_LINUX_DIR/." "$DALAMUD_WINDOWS_DIR/"
fi

dotnet restore /workspace/ArtemisRoleplayingKit.sln -p:EnableWindowsTargeting=true
dotnet build /workspace/ArtemisRoleplayingKit/RoleplayingVoiceDalamud.csproj \
  --no-restore \
  -c "$CONFIGURATION" \
  -p:Version="$VERSION" \
  -p:EnableWindowsTargeting=true

rm -f "$ARTIFACT_DIR/RoleplayingVoiceDalamud-$VERSION.zip"
cd "$OUTPUT_DIR"
zip -qr "$ARTIFACT_DIR/RoleplayingVoiceDalamud-$VERSION.zip" .

echo "Built $ARTIFACT_DIR/RoleplayingVoiceDalamud-$VERSION.zip"
