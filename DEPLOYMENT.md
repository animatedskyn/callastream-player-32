# Deployment map (Raspberry Pi OS Lite/X11)

This document lists all browser launch points and where files are deployed so Chromium is never started through `/usr/bin/chromium-browser` wrapper scripts.

## Chromium launch points in this repo

Authoritative launch path:

1. `callastream-export/systemmd/callastream-kiosk.service`
   - installed to: `/etc/systemd/system/callastream-kiosk.service`
   - starts: `/usr/bin/xinit /opt/callastream/kiosk-launch.sh -- :0 ...`

2. `callastream-export/callastream/kiosk-launch.sh`
   - installed to: `/opt/callastream/kiosk-launch.sh`
   - resolves a real Chromium binary and hard-rejects script wrappers.

Wrapper suppression paths:

3. `callastream-export/callastream/install.sh`
   - removes `chromium-browser` launch lines from:
     - `/etc/xdg/lxsession/LXDE-pi/autostart`
     - `/etc/xdg/lxsession/LXDE/autostart`
     - `/home/pi/.config/lxsession/LXDE-pi/autostart`
   - strips `Exec=...chromium-browser...` from files in `/etc/xdg/autostart/*.desktop`.

## Files and install targets

Systemd units:

- `callastream-export/systemmd/callastream-kiosk.service` -> `/etc/systemd/system/callastream-kiosk.service`
- `callastream-export/systemmd/callastream-kiosk-web.service` -> `/etc/systemd/system/callastream-kiosk-web.service`
- `callastream-export/callastream/callastream-player.service` -> `/etc/systemd/system/callastream-player.service`

Application files:

- `callastream-export/callastream/kiosk-launch.sh` -> `/opt/callastream/kiosk-launch.sh`
- `callastream-export/callastream/player.py` -> `/opt/callastream/player.py`
- `callastream-export/callastream/player.html` -> `/opt/callastream/player.html`
- `callastream-export/callastream/index.html` -> `/opt/callastream/index.html`

Logs:

- `/var/log/callastream/kiosk-launch.log` (selected binary + full args logged here)

## Install/enable

From `callastream-export/callastream`:

```bash
sudo bash install.sh
```

Manual service control:

```bash
sudo systemctl daemon-reload
sudo systemctl enable callastream-player.service callastream-kiosk-web.service callastream-kiosk.service
sudo systemctl restart callastream-player.service callastream-kiosk-web.service callastream-kiosk.service
```

## On-device verification (required)

Verify service command path:

```bash
systemctl cat callastream-kiosk.service
```

Verify launcher rejects wrappers and records binary:

```bash
tail -n 100 /var/log/callastream/kiosk-launch.log
```

Verify running Chromium executable is NOT wrapper:

```bash
pidof chromium || pidof chromium-browser
readlink -f /proc/$(pidof chromium | awk '{print $1}')/exe
```

Expected result should point to a real binary path such as:

- `/usr/lib/chromium/chromium`
- `/usr/lib/chromium-browser/chromium-browser`

and should NOT be `/usr/bin/chromium-browser`.

Verify no wrapper autostart entries remain:

```bash
rg -n "chromium-browser" /etc/xdg/lxsession /home/pi/.config/lxsession /etc/xdg/autostart
```
