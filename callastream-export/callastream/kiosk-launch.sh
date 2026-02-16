#!/usr/bin/env bash
set -euo pipefail

URL="${CALLASTREAM_URL:-http://127.0.0.1:8765/player.html}"

find_chromium_binary() {
  local candidates=(
    "/usr/lib/chromium-browser/chromium-browser"
    "/usr/lib/chromium/chromium"
    "/usr/bin/chromium"
  )

  local bin
  for bin in "${candidates[@]}"; do
    if [[ -x "$bin" ]]; then
      echo "$bin"
      return 0
    fi
  done

  return 1
}

CHROMIUM_BIN="$(find_chromium_binary || true)"
if [[ -z "$CHROMIUM_BIN" ]]; then
  echo "No Chromium binary found (checked /usr/lib/chromium-browser/chromium-browser, /usr/lib/chromium/chromium, /usr/bin/chromium)." >&2
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
  --disable-features=Translate,AutofillServerCommunication,InfiniteSessionRestore,MediaRouter \
  --disk-cache-size=10485760 \
  --media-cache-size=1048576 \
  --renderer-process-limit=2 \
  --process-per-site \
  --enable-low-end-device-mode \
  --autoplay-policy=no-user-gesture-required \
  --noerrdialogs \
  --check-for-update-interval=31536000 \
  --overscroll-history-navigation=0
