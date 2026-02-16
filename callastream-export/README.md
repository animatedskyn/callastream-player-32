# CallaStream Raspberry Pi deployment

## Kiosk/browser launch points

These files are responsible for kiosk startup:

- `systemmd/callastream-kiosk.service` - systemd unit that starts X11 + Cog kiosk as `pi`.
- `systemmd/callastream-kiosk-web.service` - local HTTP server for `player.html`.
- `callastream/cog-launch.sh` - authoritative WPE WebKit/Cog launcher.
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

Manual enable/start commands:

```bash
sudo systemctl daemon-reload
sudo systemctl enable callastream-player.service callastream-kiosk-web.service callastream-kiosk.service
sudo systemctl restart callastream-player.service callastream-kiosk-web.service callastream-kiosk.service
```

## Why this eliminates Chromium prompts

Chromium is no longer used for kiosk mode. The kiosk now launches WPE WebKit via `cog`, which has no first-run/default-browser dialogs.

The installer also removes browser entries from LXDE and XDG autostart files to prevent conflicting desktop browser launches.

## Verify on-device

```bash
journalctl -u callastream-kiosk -n 100 --no-pager
tail -n 100 /var/log/callastream/cog-launch.log
pgrep -a cog
```

For full deployment file mapping and on-device verification, see `../DEPLOYMENT.md`.
