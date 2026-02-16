#!/usr/bin/env bash
set -euo pipefail

echo "[1/7] Installing dependencies..."
apt-get update -y
apt-get install -y \
  python3 python3-requests curl \
  xserver-xorg xinit openbox unclutter \
  chromium-browser

echo "[2/7] Creating directories..."
mkdir -p /opt/callastream

echo "[3/7] Installing player files..."
install -m 0755 player.py /opt/callastream/player.py
install -m 0755 kiosk-launch.sh /opt/callastream/kiosk-launch.sh
install -m 0644 player.html /opt/callastream/player.html
install -m 0644 index.html /opt/callastream/index.html

echo "   - NOTE: this build supports slideshow + webpage only."

echo "[4/7] Installing systemd units..."
install -m 0644 callastream-player.service /etc/systemd/system/callastream-player.service
install -m 0644 ../systemmd/callastream-kiosk-web.service /etc/systemd/system/callastream-kiosk-web.service
install -m 0644 ../systemmd/callastream-kiosk.service /etc/systemd/system/callastream-kiosk.service

echo "[5/7] Enabling services..."
systemctl daemon-reload
systemctl enable callastream-player.service
systemctl enable callastream-kiosk-web.service
systemctl enable callastream-kiosk.service

echo "[6/7] Starting services..."
systemctl restart callastream-player.service
systemctl restart callastream-kiosk-web.service
systemctl restart callastream-kiosk.service

echo "[7/7] Done. Check logs:"
echo "  journalctl -u callastream-player -f"
echo "  journalctl -u callastream-kiosk -f"
