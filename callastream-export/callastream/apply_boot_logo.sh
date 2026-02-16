#!/usr/bin/env bash
set -euo pipefail

DEVICE_JSON="/opt/callastream/device.json"
STATE_DIR="/opt/callastream"
LAST_URL_FILE="$STATE_DIR/.boot_logo_last_url"
LAST_HASH_FILE="$STATE_DIR/.boot_logo_last_hash"

PLY_THEME_DIR="/usr/share/plymouth/themes/callastream"
PLY_LOGO="$PLY_THEME_DIR/logo.png"
CACHE_LOGO="$STATE_DIR/boot_logo.png"
TMP="/tmp/boot_logo_new.png"

# Grab URL
URL="$(jq -r '.boot_logo_url // empty' "$DEVICE_JSON" || true)"
if [[ -z "${URL:-}" || "$URL" == "null" ]]; then
  echo "No boot_logo_url set; nothing to do."
  exit 0
fi

echo "Downloading: $URL"
rm -f "$TMP"

# Try hard to bypass caches
curl -fsSL \
  -H "Cache-Control: no-cache" \
  -H "Pragma: no-cache" \
  "$URL" -o "$TMP"

# Basic sanity check (must be PNG)
file "$TMP" | grep -qi 'PNG image data' || { echo "Downloaded file is not PNG"; exit 1; }

NEW_HASH="$(sha256sum "$TMP" | awk '{print $1}')"
OLD_HASH=""
[[ -f "$LAST_HASH_FILE" ]] && OLD_HASH="$(cat "$LAST_HASH_FILE" || true)"

# If the bytes are identical, skip (prevents constant initramfs rebuilds)
if [[ -n "$OLD_HASH" && "$NEW_HASH" == "$OLD_HASH" ]]; then
  echo "Boot logo content unchanged; skipping."
  exit 0
fi

# Update cached logo used by CallaStream
install -m 0644 "$TMP" "$CACHE_LOGO"

# Update plymouth theme logo
install -m 0644 "$TMP" "$PLY_LOGO"

# Rebuild initramfs for current kernel
K="$(uname -r)"
echo "Rebuilding initramfs for $K ..."
update-initramfs -u -k "$K"

# Mark applied
echo "$URL" > "$LAST_URL_FILE"
echo "$NEW_HASH" > "$LAST_HASH_FILE"

echo "Boot logo applied successfully."
