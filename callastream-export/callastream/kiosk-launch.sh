#!/usr/bin/env bash
set -euo pipefail

DEFAULT_URL="http://127.0.0.1:8765/player.html"
STATE_JSON="/opt/callastream/state.json"
DEVICE_JSON="/opt/callastream/device.json"
LOG_FILE="${CALLASTREAM_KIOSK_LOG:-/var/log/callastream-kiosk.log}"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

extract_first_url_from_json() {
  local file="$1"
  [[ -f "$file" ]] || return 1

  python3 - "$file" <<'PY'
import json
import sys

path = sys.argv[1]
keys = (
    "kiosk_url",
    "player_url",
    "launch_url",
    "url",
    "content_url",
    "web_url",
)

try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    sys.exit(1)

if isinstance(data, dict):
    for k in keys:
        v = data.get(k)
        if isinstance(v, str) and v.strip().startswith(("http://", "https://")):
            print(v.strip())
            sys.exit(0)

print("")
PY
}

resolve_url() {
  local url=""

  if [[ -n "${CALLASTREAM_URL:-}" ]]; then
    url="$CALLASTREAM_URL"
  fi

  if [[ -z "$url" ]]; then
    url="$(extract_first_url_from_json "$STATE_JSON" || true)"
  fi

  if [[ -z "$url" ]]; then
    url="$(extract_first_url_from_json "$DEVICE_JSON" || true)"
  fi

  if [[ -z "$url" ]]; then
    url="$DEFAULT_URL"
  fi

  printf '%s\n' "$url"
}

is_script_wrapper() {
  local candidate="$1"
  head -c 2 "$candidate" 2>/dev/null | grep -q '^#!'
}

is_real_elf_binary() {
  local candidate="$1"
  [[ -x "$candidate" ]] || return 1

  if is_script_wrapper "$candidate"; then
    return 1
  fi

  if command -v file >/dev/null 2>&1; then
    file -b "$candidate" | grep -qi 'ELF' || return 1
  fi

  return 0
}

find_cog_binary() {
  local candidates=(
    "/usr/bin/cog"
    "/usr/local/bin/cog"
  )

  local bin
  for bin in "${candidates[@]}"; do
    if is_real_elf_binary "$bin"; then
      echo "$bin"
      return 0
    fi
  done

  return 1
}

COG_BIN="$(find_cog_binary || true)"
if [[ -z "$COG_BIN" ]]; then
  log "ERROR: Cog is not installed or no valid Cog ELF binary was found."
  exit 1
fi

URL="$(resolve_url)"

# Ensure only one kiosk instance.
if pgrep -x cog >/dev/null 2>&1; then
  log "Existing cog process detected; terminating stale instances."
  pkill -x cog || true
  sleep 1
fi

xset -dpms
xset s off
xset s noblank

if command -v unclutter >/dev/null 2>&1; then
  unclutter -idle 0 -root &
fi

COG_ARGS=(
  --platform=x11
  --fullscreen
  "$URL"
)

log "Chosen URL: $URL"
log "Command: $COG_BIN ${COG_ARGS[*]}"

exec "$COG_BIN" "${COG_ARGS[@]}"
