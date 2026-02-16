#!/usr/bin/env bash
set -euo pipefail

URL="${CALLASTREAM_URL:-http://127.0.0.1:8765/player.html}"
LOG_FILE="${CALLASTREAM_KIOSK_LOG:-/var/log/callastream/cog-launch.log}"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
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

    if [[ -x "$bin" ]] && is_script_wrapper "$bin"; then
      log "Rejected wrapper script: $bin"
    fi
  done

  return 1
}

COG_BIN="$(find_cog_binary || true)"
if [[ -z "$COG_BIN" ]]; then
  log "ERROR: No real Cog ELF binary found (wrapper scripts are intentionally rejected)."
  exit 1
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

log "Using Cog binary: $COG_BIN"
log "Launching args: ${COG_ARGS[*]}"

exec "$COG_BIN" "${COG_ARGS[@]}"
