#!/usr/bin/env bash
set -euo pipefail

echo "[1/6] Installing dependencies..."
apt-get update -y
apt-get install -y python3 python3-requests curl

echo "[2/6] Creating directories..."
mkdir -p /opt/callastream

echo "[3/6] Installing player files..."
install -m 0755 player.py /opt/callastream/player.py
install -m 0644 player.html /opt/callastream/player.html
install -m 0644 index.html /opt/callastream/index.html

echo "   - NOTE: this build supports slideshow + webpage only."

echo "[4/6] Installing systemd unit..."
install -m 0644 callastream-player.service /etc/systemd/system/callastream-player.service

echo "[5/6] Enabling service..."
systemctl daemon-reload
systemctl enable callastream-player.service

echo "[6/6] Starting service..."
systemctl restart callastream-player.service

echo "Done. Check logs: journalctl -u callastream-player -f"
