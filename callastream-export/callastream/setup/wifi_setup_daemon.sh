#!/usr/bin/env bash
set -euo pipefail

IFACE="${CALLASTREAM_WIFI_IFACE:-wlan0}"
SETUP_DIR="/opt/callastream/setup"
FORCE_FILE="$SETUP_DIR/FORCE_SETUP"
CREDS_FILE="$SETUP_DIR/CREDS.json"

log(){ echo "[wifi-setup] $(date '+%F %T') $*"; }

# If we're already connected and not forced into setup, exit cleanly
current_ssid="$(iwgetid -r 2>/dev/null || true)"
if [[ ! -f "$FORCE_FILE" && -n "$current_ssid" ]]; then
  log "WiFi already connected to SSID='$current_ssid' and FORCE_SETUP not present. Exiting."
  exit 0
fi

log "Entering WiFi setup mode (FORCE_SETUP present or not connected)."

# Requirements
if ! command -v hostapd >/dev/null 2>&1 || ! command -v dnsmasq >/dev/null 2>&1; then
  log "Installing required packages (hostapd, dnsmasq)..."
  apt-get update -y
  apt-get install -y hostapd dnsmasq
fi

# Stop services that may conflict
systemctl stop hostapd 2>/dev/null || true
systemctl stop dnsmasq 2>/dev/null || true

# Prep runtime config
RUN_DIR="/run/callastream-setup"
mkdir -p "$RUN_DIR"

AP_IP="192.168.4.1"
AP_NET="192.168.4.0/24"
DHCP_START="192.168.4.50"
DHCP_END="192.168.4.150"

cat >"$RUN_DIR/hostapd.conf" <<EOF
interface=$IFACE
ssid=callastream-setup
hw_mode=g
channel=6
wmm_enabled=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=callastream
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

cat >"$RUN_DIR/dnsmasq.conf" <<EOF
interface=$IFACE
bind-interfaces
dhcp-range=$DHCP_START,$DHCP_END,255.255.255.0,12h
dhcp-option=3,$AP_IP
dhcp-option=6,$AP_IP
address=/#/$AP_IP
log-queries
log-dhcp
EOF

# Configure interface
log "Configuring $IFACE with static IP $AP_IP..."
ip link set "$IFACE" down || true
ip addr flush dev "$IFACE" || true
ip addr add "$AP_IP/24" dev "$IFACE"
ip link set "$IFACE" up

# Redirect all HTTP to our portal port (8080)
log "Setting captive portal redirect..."
iptables -t nat -D PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-ports 8080 2>/dev/null || true
iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-ports 8080

# Start AP + DHCP/DNS
log "Starting dnsmasq + hostapd..."
dnsmasq --conf-file="$RUN_DIR/dnsmasq.conf" --no-daemon &
DNSMASQ_PID=$!
hostapd "$RUN_DIR/hostapd.conf" &
HOSTAPD_PID=$!

# Start portal
log "Starting portal on http://$AP_IP (port 80 redirected to 8080)..."
rm -f "$CREDS_FILE"
python3 "$SETUP_DIR/portal.py" &
PORTAL_PID=$!

log "Waiting for credentials..."
while [[ ! -s "$CREDS_FILE" ]]; do sleep 1; done

SSID="$(python3 -c 'import json;print(json.load(open("'"$CREDS_FILE"'"))["ssid"])')"
PSK="$(python3 -c 'import json;print(json.load(open("'"$CREDS_FILE"'"))["psk"])')"
log "Got SSID='$SSID' (password length ${#PSK})."

# Cleanup AP services before connecting as client
log "Stopping portal/AP services..."
kill "$PORTAL_PID" 2>/dev/null || true
kill "$HOSTAPD_PID" 2>/dev/null || true
kill "$DNSMASQ_PID" 2>/dev/null || true
sleep 1
iptables -t nat -D PREROUTING -i "$IFACE" -p tcp --dport 80 -j REDIRECT --to-ports 8080 2>/dev/null || true

# Connect to WiFi as client (NetworkManager preferred; fallback to wpa_supplicant)
if command -v nmcli >/dev/null 2>&1; then
  log "Using NetworkManager (nmcli) to connect..."
  nmcli radio wifi on || true
  nmcli dev set "$IFACE" managed yes || true
  if [[ -n "$PSK" ]]; then
    nmcli dev wifi connect "$SSID" password "$PSK" ifname "$IFACE"
  else
    nmcli dev wifi connect "$SSID" ifname "$IFACE"
  fi
else
  log "nmcli not found; writing /etc/wpa_supplicant/wpa_supplicant.conf..."
  WPA="/etc/wpa_supplicant/wpa_supplicant.conf"
  mkdir -p /etc/wpa_supplicant
  if [[ -n "$PSK" ]]; then
    wpa_passphrase "$SSID" "$PSK" > "$WPA"
  else
    cat >"$WPA" <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=US
network={
  ssid="$SSID"
  key_mgmt=NONE
}
EOF
  fi
  wpa_cli -i "$IFACE" reconfigure || true
fi

# Mark setup complete and reboot
log "WiFi connected. Clearing setup marker and rebooting..."
rm -f "$FORCE_FILE" || true
sync
systemctl reboot
exit 0
