# Deployment map (Raspberry Pi OS Lite/X11)

This document lists all kiosk launch points and deployment paths for the WPE WebKit + Cog kiosk.

## Kiosk launch points in this repo

Authoritative launch path:

1. `callastream-export/systemmd/callastream-kiosk.service`
   - installed to: `/etc/systemd/system/callastream-kiosk.service`
   - starts: `/usr/bin/xinit /opt/callastream/kiosk-launch.sh -- :0 ...`

2. `callastream-export/callastream/kiosk-launch.sh`
   - installed to: `/opt/callastream/kiosk-launch.sh`
   - resolves kiosk URL from `state.json` / `device.json` with a local default fallback.
   - verifies a real `cog` binary and launches full-screen kiosk mode.

Autostart conflict cleanup path:

3. `callastream-export/callastream/install.sh`
   - removes browser launch lines from:
     - `/etc/xdg/lxsession/LXDE-pi/autostart`
     - `/etc/xdg/lxsession/LXDE/autostart`
     - `/home/pi/.config/lxsession/LXDE-pi/autostart`
   - strips browser `Exec=...` lines from files in `/etc/xdg/autostart/*.desktop`.

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

- `/var/log/callastream-kiosk.log` (selected URL + full command logged here)

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

## On-device verification

Verify service command path:

```bash
systemctl cat callastream-kiosk.service
```

Verify launcher log and final URL/command:

```bash
tail -n 100 /var/log/callastream-kiosk.log
```

Verify running kiosk executable is Cog:

```bash
pgrep -a cog
readlink -f /proc/$(pgrep -o cog)/exe
```

Expected executable:

- `/usr/bin/cog`

Verify no desktop browser autostart entries remain:

```bash
rg -n "g[o]ogle-c[h]rome|\bc[h]rome\b|\bcog\b" /etc/xdg/lxsession /home/pi/.config/lxsession /etc/xdg/autostart
```
