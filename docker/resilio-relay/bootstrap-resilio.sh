#!/usr/bin/env bash
set -Eeuo pipefail

API_URL="${RESILIO_API_URL:-http://127.0.0.1:8888/gui/}"
API_HOST="${RESILIO_API_HOST:-localhost:8888}"
STATE_DIR="${RESILIO_BOOTSTRAP_STATE_DIR:-/mnt/sync/config/artemis-relay}"
COOKIE_FILE="${STATE_DIR}/cookies.txt"
PASSWORD_FILE="${STATE_DIR}/webui-password"

IDENTITY="${RESILIO_IDENTITY:-Artemis Relay Docker}"
WEBUI_USER="${RESILIO_WEBUI_USER:-artemis-relay}"
WEBUI_PASSWORD="${RESILIO_WEBUI_PASSWORD:-}"
SHARE_LINK="${RESILIO_SHARE_LINK:-}"
SYNC_PATH="${RESILIO_SYNC_PATH:-/mnt/mounted_folders/Artemis Dialogue Server}"
MONITOR_INTERVAL="${RESILIO_MONITOR_INTERVAL_SECONDS:-30}"
RELAY_ENABLED="${ARTEMIS_RELAY_ENABLED:-true}"
RELAY_SHIM_DLL="${ARTEMIS_RELAY_SHIM_DLL:-/opt/artemis/relay-shim/ArtemisRelayShim.dll}"
RELAY_AUDIO_PORT="${ARTEMIS_RELAY_AUDIO_PORT:-5670}"
RELAY_SERVER_LIST_PORT="${ARTEMIS_RELAY_SERVER_LIST_PORT:-5677}"
RELAY_INFORMATION_PORT="${ARTEMIS_RELAY_INFORMATION_PORT:-5684}"

mkdir -p "${STATE_DIR}"
chmod 700 "${STATE_DIR}" || true

log() {
  printf '[artemis-bootstrap] %s\n' "$*"
}

timestamp_ms() {
  printf '%s000' "$(date +%s)"
}

curl_base() {
  curl -fsS -H "Host: ${API_HOST}" "$@"
}

curl_auth() {
  curl_base -u "${WEBUI_USER}:${WEBUI_PASSWORD}" "$@"
}

shutdown() {
  local status=$?
  if [[ -n "${RELAY_PID:-}" ]] && kill -0 "${RELAY_PID}" 2>/dev/null; then
    kill "${RELAY_PID}" 2>/dev/null || true
    wait "${RELAY_PID}" 2>/dev/null || true
  fi
  if [[ -n "${RESILIO_PID:-}" ]] && kill -0 "${RESILIO_PID}" 2>/dev/null; then
    kill "${RESILIO_PID}" 2>/dev/null || true
    wait "${RESILIO_PID}" 2>/dev/null || true
  fi
  exit "${status}"
}

wait_for_resilio() {
  log "waiting for Resilio Web UI API at ${API_URL}"
  until [[ "$(curl -sS -o /dev/null -w '%{http_code}' -H "Host: ${API_HOST}" "${API_URL}" || true)" =~ ^(200|401)$ ]]; do
    sleep 2
  done
}

extract_token() {
  sed -n 's/.*<div id=.token.[^>]*>\([^<]*\).*/\1/p'
}

get_token_noauth() {
  curl_base -c "${COOKIE_FILE}" -X POST "${API_URL%/}/token.html?t=$(timestamp_ms)" | extract_token
}

get_token_auth() {
  curl_auth -c "${COOKIE_FILE}" -X POST "${API_URL%/}/token.html?t=$(timestamp_ms)" | extract_token
}

api_noauth() {
  local token="$1"
  local action="$2"
  shift 2
  curl_base -b "${COOKIE_FILE}" -G \
    --data-urlencode "token=${token}" \
    --data-urlencode "action=${action}" \
    --data-urlencode "t=$(timestamp_ms)" \
    "$@" \
    "${API_URL}"
}

api_auth() {
  local token="$1"
  local action="$2"
  shift 2
  curl_auth -b "${COOKIE_FILE}" -G \
    --data-urlencode "token=${token}" \
    --data-urlencode "action=${action}" \
    --data-urlencode "t=$(timestamp_ms)" \
    "$@" \
    "${API_URL}"
}

ensure_password() {
  if [[ -n "${WEBUI_PASSWORD}" ]]; then
    return
  fi

  if [[ -f "${PASSWORD_FILE}" ]]; then
    WEBUI_PASSWORD="$(<"${PASSWORD_FILE}")"
    return
  fi

  WEBUI_PASSWORD="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
  printf '%s' "${WEBUI_PASSWORD}" >"${PASSWORD_FILE}"
  chmod 600 "${PASSWORD_FILE}" || true
  log "generated Web UI password and stored it at ${PASSWORD_FILE}"
}

is_auth_enabled() {
  local status
  status="$(curl -sS -o /dev/null -w '%{http_code}' -H "Host: ${API_HOST}" "${API_URL}" || true)"
  [[ "${status}" == "401" ]]
}

accept_terms_if_needed() {
  if is_auth_enabled; then
    log "Resilio Web UI auth is already enabled; terms appear accepted"
    return
  fi

  if [[ "${RESILIO_ACCEPT_TERMS:-false}" != "true" ]]; then
    log "RESILIO_ACCEPT_TERMS is not true; waiting instead of accepting terms"
    return 1
  fi

  local token response
  token="$(get_token_noauth)"
  if [[ -z "${token}" ]]; then
    log "failed to obtain unauthenticated Resilio token"
    return 1
  fi

  log "accepting Resilio terms via local API"
  response="$(api_noauth "${token}" setlicenseagreed \
    --data-urlencode "value=true" \
    --data-urlencode "username=${WEBUI_USER}" \
    --data-urlencode "newpwd=${WEBUI_PASSWORD}" \
    --data-urlencode "oldpwd=")"

  if ! grep -q '"error":0' <<<"${response}"; then
    log "terms acceptance failed: ${response}"
    return 1
  fi
}

set_identity() {
  local token
  token="$(get_token_auth)"
  log "setting Resilio identity"
  api_auth "${token}" setuseridentity \
    --data-urlencode "username=${IDENTITY}" >/dev/null
}

folders_response() {
  local token
  token="$(get_token_auth)"
  api_auth "${token}" getsyncfolders || true
}

folder_exists() {
  local response escaped_path
  response="$(folders_response)"
  escaped_path="$(printf '%s' "${SYNC_PATH}" | sed 's/[.[\*^$()+?{}|]/\\&/g')"
  grep -q "\"path\":\"${escaped_path}\"" <<<"${response}"
}

add_share_if_needed() {
  if [[ -z "${SHARE_LINK}" ]]; then
    log "RESILIO_SHARE_LINK is empty; waiting"
    return 1
  fi

  if [[ "${SYNC_PATH}" != /mnt/* ]]; then
    log "RESILIO_SYNC_PATH must be under /mnt for the official 2.x image: ${SYNC_PATH}"
    return 1
  fi

  if folder_exists; then
    log "Resilio share is already configured at ${SYNC_PATH}"
    return
  fi

  local token response
  token="$(get_token_auth)"

  log "adding managed read-only Resilio share link"
  response="$(api_auth "${token}" addlink \
    --data-urlencode "link=${SHARE_LINK}" \
    --data-urlencode "path=${SYNC_PATH}" \
    --data-urlencode "selectivesync=false")"

  if ! grep -q '"error":0' <<<"${response}"; then
    log "share add failed: ${response}"
    return 1
  fi
}

folder_status() {
  local response object value
  response="$(folders_response)"
  object="$(printf '%s' "${response}" | sed 's/},{/}\n{/g' | grep "\"path\":\"${SYNC_PATH}\"" || true)"

  if [[ -z "${object}" ]]; then
    printf 'share_not_found\n'
    return
  fi

  printf 'path=%s' "${SYNC_PATH}"
  for field in status has_key onlinepeerscount files queue_download_files queue_download_size firstsynccompleted ismanaged iswritable access; do
    value="$(printf '%s' "${object}" | sed -n "s/.*\"${field}\":\\(\"[^\"]*\"\\|[^,}\\]]*\\).*/\\1/p")"
    if [[ -n "${value}" ]]; then
      value="${value%\"}"
      value="${value#\"}"
      printf ' %s=%s' "${field}" "${value}"
    fi
  done
  printf '\n'
}

relay_payload_ready() {
  [[ -f "${SYNC_PATH}/CachedTTSRelay.dll" ]] \
    && [[ -f "${SYNC_PATH}/CachedTTSRelay.deps.json" ]] \
    && [[ -f "${SYNC_PATH}/RoleplayingVoiceCore.dll" ]] \
    && [[ -d "${SYNC_PATH}/NPC Dialogue Cache" ]]
}

start_relay_if_ready() {
  if [[ "${RELAY_ENABLED}" != "true" ]]; then
    return
  fi

  if [[ -n "${RELAY_PID:-}" ]] && kill -0 "${RELAY_PID}" 2>/dev/null; then
    return
  fi

  if ! relay_payload_ready; then
    log "relay status: waiting_for_payload path='${SYNC_PATH}' required='CachedTTSRelay.dll,CachedTTSRelay.deps.json,RoleplayingVoiceCore.dll,NPC Dialogue Cache/'"
    return
  fi

  log "starting relay shim from ${RELAY_SHIM_DLL}"
  ARTEMIS_RELAY_PAYLOAD_PATH="${SYNC_PATH}" \
    dotnet "${RELAY_SHIM_DLL}" &
  RELAY_PID="$!"
}

port_hex() {
  printf '%04X' "$1"
}

port_listening() {
  local port="$1"
  local hex
  hex="$(port_hex "${port}")"
  grep -Eiq ":0*${hex}[[:space:]]+[0-9A-F]+:[0-9A-F]{4}[[:space:]]+0A" /proc/net/tcp /proc/net/tcp6 2>/dev/null
}

relay_status() {
  if [[ "${RELAY_ENABLED}" != "true" ]]; then
    printf 'disabled\n'
    return
  fi

  if [[ -z "${RELAY_PID:-}" ]]; then
    printf 'not_started\n'
    return
  fi

  if ! kill -0 "${RELAY_PID}" 2>/dev/null; then
    printf 'exited\n'
    return
  fi

  printf 'pid=%s' "${RELAY_PID}"
  for port in "${RELAY_AUDIO_PORT}" "${RELAY_SERVER_LIST_PORT}" "${RELAY_INFORMATION_PORT}"; do
    if port_listening "${port}"; then
      printf ' port_%s=listening' "${port}"
    else
      printf ' port_%s=closed' "${port}"
    fi
  done
  printf '\n'
}

bootstrap_until_ready() {
  wait_for_resilio
  ensure_password

  until accept_terms_if_needed; do
    sleep "${MONITOR_INTERVAL}"
  done

  set_identity

  until add_share_if_needed; do
    sleep "${MONITOR_INTERVAL}"
  done

  log "bootstrap complete; waiting for sync content"
}

trap shutdown INT TERM EXIT

/usr/bin/run_sync "$@" &
RESILIO_PID="$!"

bootstrap_until_ready

while kill -0 "${RESILIO_PID}" 2>/dev/null; do
  start_relay_if_ready
  log "sync status: $(folder_status)"
  log "relay status: $(relay_status)"
  sleep "${MONITOR_INTERVAL}"
done

wait "${RESILIO_PID}"
