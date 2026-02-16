# CallaStream Raspberry Pi deployment

## Kiosk/browser launch points

These files are responsible for web UI startup:

- `systemmd/callastream-kiosk.service` - systemd unit that starts X11 + Chromium kiosk as `pi`.
- `systemmd/callastream-kiosk-web.service` - local HTTP server for `player.html`.
- `callastream/kiosk-launch.sh` - browser launcher (uses Chromium binary directly, not the `chromium-browser` wrapper).
- `callastream/setup/wifi_setup_daemon.sh` - first-boot AP workflow (`callastream-setup`) and reboot after Wi-Fi save.

## Install and enable on Raspberry Pi OS Lite/X11

> Run as root from `callastream-export/callastream`.

```bash
sudo bash install.sh
```

This installs:

- player/poller service: `callastream-player.service`
- local web service: `callastream-kiosk-web.service`
- kiosk UI service: `callastream-kiosk.service`

Manual enable/start commands (if needed):

```bash
sudo systemctl daemon-reload
sudo systemctl enable callastream-player.service callastream-kiosk-web.service callastream-kiosk.service
sudo systemctl restart callastream-player.service callastream-kiosk-web.service callastream-kiosk.service
```

## Why this avoids the Pi Zero 2 W Chromium warning

`kiosk-launch.sh` probes and executes Chromium's real ELF binary directly and explicitly rejects script wrappers. This bypasses the `/usr/bin/chromium-browser` low-RAM warning dialog path entirely.

It also adds low-memory kiosk flags for 512MB devices:

- disables first-run/default-browser dialogs
- disables crash/session bubbles and most background features
- limits renderer process count
- enables low-end device mode
- keeps kiosk full-screen with no error dialogs


The installer also removes any `chromium-browser` entries from LXDE autostart files so desktop autostart cannot reintroduce the wrapper popup during boot.

## First-boot flow (no stored Wi-Fi)

1. Device boots and shows boot logo.
2. Wi-Fi setup mode starts AP SSID `callastream-setup`.
3. You connect and submit Wi-Fi credentials.
4. Device saves credentials and reboots automatically.
5. Device boots again, shows boot logo, then claim/player screen.
