#!/usr/bin/env bash
set -euo pipefail

URL="${CALLASTREAM_URL:-http://127.0.0.1:8765/player.html}"

is_real_chromium_binary() {
  local candidate="$1"

  [[ -x "$candidate" ]] || return 1

  # Avoid wrapper scripts (the low-RAM warning comes from wrapper shell scripts).
  if head -c 2 "$candidate" 2>/dev/null | grep -q '^#!'; then
    return 1
  fi

  return 0
}

find_chromium_binary() {
  local candidates=(
    "/usr/lib/chromium-browser/chromium-browser"
    "/usr/lib/chromium/chromium"
    "/usr/lib/chromium/chrome"
    "/usr/bin/chromium"
  )

  local bin
  for bin in "${candidates[@]}"; do
    if is_real_chromium_binary "$bin"; then
      echo "$bin"
      return 0
    fi
  done

  return 1
}

CHROMIUM_BIN="$(find_chromium_binary || true)"
if [[ -z "$CHROMIUM_BIN" ]]; then
  echo "No real Chromium binary found (wrapper scripts are intentionally rejected)." >&2
  exit 1
fi

xset -dpms
xset s off
xset s noblank

if command -v unclutter >/dev/null 2>&1; then
  unclutter -idle 0 -root &
fi

exec "$CHROMIUM_BIN" \
  --kiosk "$URL" \
  --no-first-run \
  --no-default-browser-check \
  --disable-session-crashed-bubble \
  --disable-infobars \
  --disable-component-update \
  --disable-background-networking \
  --disable-sync \
  --disable-extensions \
  --disable-translate \
  --disable-features=Translate,AutofillServerCommunication,InfiniteSessionRestore,MediaRouter \
  --disk-cache-size=10485760 \
  --media-cache-size=1048576 \
  --renderer-process-limit=2 \
  --process-per-site \
  --enable-low-end-device-mode \
  --autoplay-policy=no-user-gesture-required \
  --noerrdialogs \
  --check-for-update-interval=31536000 \
  --overscroll-history-navigation=0 \
  --disable-dev-shm-usage \
  --disable-gpu-shader-disk-cache
