# CallaStream Raspberry Pi deployment

## Kiosk launch points

These files are responsible for kiosk startup:

- `systemmd/callastream-kiosk.service` - systemd unit that starts X11 + WPE WebKit kiosk as `pi`.
- `systemmd/callastream-kiosk-web.service` - local HTTP server for `player.html`.
- `callastream/kiosk-launch.sh` - authoritative kiosk launcher that starts `cog` full-screen.
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

## Why this has zero first-run dialogs

The kiosk engine is WPE WebKit via `cog`, not a desktop browser with first-run prompts.

A single systemd unit starts `kiosk-launch.sh`, and install cleanup removes browser autostart entries so there is only one kiosk instance.

## Verify on-device

```bash
journalctl -u callastream-kiosk -n 100 --no-pager
tail -n 100 /var/log/callastream-kiosk.log
pgrep -a cog
```

For full deployment file mapping and on-device verification, see `../DEPLOYMENT.md`.
