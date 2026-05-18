#!/usr/bin/env bash
set -Eeuo pipefail

PAYLOAD_DIR="${ARTEMIS_RELAY_CONTAINER_PAYLOAD_PATH:-/payload}"
ENTRY_DLL="${ARTEMIS_RELAY_ENTRY_DLL:-CachedTTSRelay.dll}"
RUNTIME_CONFIG="${PAYLOAD_DIR}/${ENTRY_DLL%.dll}.runtimeconfig.json"

log() {
  printf '[artemis-relay-runtime] %s\n' "$*"
}

if [[ ! -d "${PAYLOAD_DIR}" ]]; then
  log "payload directory does not exist: ${PAYLOAD_DIR}"
  exit 66
fi

if [[ ! -f "${PAYLOAD_DIR}/${ENTRY_DLL}" ]]; then
  log "relay entrypoint not found: ${PAYLOAD_DIR}/${ENTRY_DLL}"
  exit 66
fi

if [[ ! -f "${RUNTIME_CONFIG}" ]]; then
  log "runtime config not found: ${RUNTIME_CONFIG}"
  exit 66
fi

if grep -q '"Microsoft.WindowsDesktop.App"' "${RUNTIME_CONFIG}"; then
  log "mounted relay payload targets Microsoft.WindowsDesktop.App and cannot run in a Linux .NET runtime container"
  log "publish a Linux-compatible relay build without WindowsDesktop/WinForms, then mount that payload at ${PAYLOAD_DIR}"
  exit 78
fi

cd "${PAYLOAD_DIR}"
exec dotnet "${ENTRY_DLL}" "$@"
