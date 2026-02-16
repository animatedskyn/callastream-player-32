# Deployment map (Raspberry Pi OS Lite/X11)

This document lists all kiosk launch points and deployment paths for the WPE WebKit + Cog kiosk.

## Kiosk launch points in this repo

Authoritative launch path:

1. `callastream-export/systemmd/callastream-kiosk.service`
   - installed to: `/etc/systemd/system/callastream-kiosk.service`
   - starts: `/usr/bin/xinit /opt/callastream/cog-launch.sh -- :0 ...`

2. `callastream-export/callastream/cog-launch.sh`
   - installed to: `/opt/callastream/cog-launch.sh`
   - resolves a real Cog ELF binary and hard-rejects script wrappers.
   - launches fullscreen `cog` pointed at the CallaStream local URL.

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

- `callastream-export/callastream/cog-launch.sh` -> `/opt/callastream/cog-launch.sh`
- `callastream-export/callastream/player.py` -> `/opt/callastream/player.py`
- `callastream-export/callastream/player.html` -> `/opt/callastream/player.html`
- `callastream-export/callastream/index.html` -> `/opt/callastream/index.html`

Logs:

- `/var/log/callastream/cog-launch.log` (selected binary + full args logged here)

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

Verify launcher log and final URL/binary:

```bash
tail -n 100 /var/log/callastream/cog-launch.log
```

Verify running kiosk executable is Cog:

```bash
pgrep -a cog
readlink -f /proc/$(pgrep -o cog)/exe
```

Expected executable:

- `/usr/bin/cog`

Verify no desktop autostart browser entries remain:

```bash
rg -n "chromium|\bcog\b" /etc/xdg/lxsession /home/pi/.config/lxsession /etc/xdg/autostart
```
