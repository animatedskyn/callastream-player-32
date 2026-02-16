#!/usr/bin/env bash
set -euo pipefail

echo "[1/9] Installing dependencies..."
apt-get update -y
apt-get install -y \
  python3 python3-requests curl \
  xserver-xorg xinit openbox unclutter \
  cog wpewebkit-driver

echo "[2/9] Creating directories..."
mkdir -p /opt/callastream /var/log/callastream

if id -u pi >/dev/null 2>&1; then
  chown -R pi:pi /var/log/callastream
fi

echo "[3/9] Installing player files..."
install -m 0755 player.py /opt/callastream/player.py
install -m 0755 cog-launch.sh /opt/callastream/cog-launch.sh
rm -f /opt/callastream/kiosk-launch.sh
install -m 0644 player.html /opt/callastream/player.html
install -m 0644 index.html /opt/callastream/index.html

echo "   - NOTE: this build supports slideshow + webpage only."

echo "[4/9] Installing systemd units..."
install -m 0644 callastream-player.service /etc/systemd/system/callastream-player.service
install -m 0644 ../systemmd/callastream-kiosk-web.service /etc/systemd/system/callastream-kiosk-web.service
install -m 0644 ../systemmd/callastream-kiosk.service /etc/systemd/system/callastream-kiosk.service

echo "[5/9] Preventing desktop/autostart browser conflicts..."
for f in \
  /etc/xdg/lxsession/LXDE-pi/autostart \
  /etc/xdg/lxsession/LXDE/autostart \
  /home/pi/.config/lxsession/LXDE-pi/autostart; do
  if [[ -f "$f" ]]; then
    # Keep systemd service as the single kiosk launch authority.
    sed -i '/chromium/d;/^@cog /d;/\/usr\/bin\/cog /d' "$f"
  fi
done

if [[ -d /etc/xdg/autostart ]]; then
  find /etc/xdg/autostart -maxdepth 1 -type f -name '*.desktop' -print0 | while IFS= read -r -d '' desktop_file; do
    sed -i '/Exec=.*chromium/d;/Exec=.*\bcog\b/d' "$desktop_file"
  done
fi

echo "[6/9] Enabling services..."
systemctl daemon-reload
systemctl enable callastream-player.service
systemctl enable callastream-kiosk-web.service
systemctl enable callastream-kiosk.service

echo "[7/9] Starting services..."
systemctl restart callastream-player.service
systemctl restart callastream-kiosk-web.service
systemctl restart callastream-kiosk.service

echo "[8/9] Verifying no desktop browser autostart entries remain..."
rg -n "chromium|\bcog\b" /etc/xdg/lxsession /home/pi/.config/lxsession /etc/xdg/autostart 2>/dev/null || true

echo "[9/9] Done. Check logs:"
echo "  journalctl -u callastream-player -f"
echo "  journalctl -u callastream-kiosk -f"
echo "  tail -f /var/log/callastream/cog-launch.log"
