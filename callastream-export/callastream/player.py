#!/usr/bin/env python3
import subprocess
import json
import os
import hashlib
import time
from pathlib import Path
from urllib.parse import urlparse

import requests

import socket

def is_online(host: str = "callastream.com", port: int = 443, timeout: float = 3.0) -> bool:
    """Return True if we can open a TCP connection to the CallaStream server."""
    try:
        sock = socket.create_connection((host, port), timeout=timeout)
        sock.close()
        return True
    except Exception:
        return False



# Defaults (can be overridden via /opt/callastream/device.json)
DEFAULT_SERVER_URL = "https://callastream.com"

DEVICE_JSON = Path("/opt/callastream/device.json")
STATE_JSON  = Path("/opt/callastream/state.json")
BOOT_LOGO_PATH = Path("/opt/callastream/boot_logo.png")
MACHINE_ID_PATH = Path("/etc/machine-id")

# Wi-Fi setup mode marker (created/managed by /opt/callastream/setup/wifi_setup_daemon.sh)
WIFI_SETUP_FORCE_FILE = Path("/opt/callastream/setup/FORCE_SETUP")

# ✅ NEW: persistent state for last processed command (prevents reboot loops)
COMMAND_STATE_JSON = Path("/opt/callastream/command_state.json")

# Service env overrides
POLL_SECONDS = float(os.environ.get("CALLASTREAM_POLL_SECONDS", "5"))
BOOTSTRAP_EVERY = int(os.environ.get("CALLASTREAM_BOOTSTRAP_EVERY", "600"))  # seconds


def kick_bootlogo_apply():
    """
    Start the oneshot service that applies boot logo + rebuilds initramfs.
    Fire-and-forget so we don't block the player loop.
    """
    try:
        subprocess.Popen(
            ["systemctl", "start", "callastream-bootlogo.service"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        # Don't crash signage playback if systemctl isn't available for some reason
        pass


def read_json(path: Path, default=None):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default if default is not None else {}


def write_json_atomic(path: Path, data: dict):
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2), encoding="utf-8")
    os.replace(tmp, path)


def command_fingerprint(cmd: dict) -> str:
    """Stable fingerprint for a command dict."""
    if not isinstance(cmd, dict):
        return ""
    # Prefer explicit ids if present
    for k in ("id", "command_id", "uuid"):
        v = cmd.get(k)
        if isinstance(v, str) and v.strip():
            return hashlib.sha256(v.strip().encode("utf-8", errors="ignore")).hexdigest()

    try:
        raw = json.dumps(cmd, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    except Exception:
        raw = repr(cmd)
    return hashlib.sha256(raw.encode("utf-8", errors="ignore")).hexdigest()


def load_last_command_fingerprint() -> str:
    data = read_json(COMMAND_STATE_JSON, default={})
    if isinstance(data, dict):
        return str(data.get("last_fingerprint") or "")
    return ""


def save_last_command_fingerprint(fp: str) -> None:
    try:
        write_json_atomic(COMMAND_STATE_JSON, {"last_fingerprint": fp, "updated_at": int(time.time())})
    except Exception:
        # If we can't write, worst-case we might re-run a command after reboot.
        pass


def attempt_command_ack(server: str, device_uuid: str, cmd: dict) -> None:
    """Best-effort command ACK. Safe if the server endpoint isn't present yet."""
    try:
        url = server.rstrip("/") + f"/wp-json/callastream/v1/device/{device_uuid}/command-ack"
        requests.post(url, json={"command": cmd}, timeout=5)
    except Exception:
        pass


def trigger_reboot() -> None:
    """Reboot the Pi. Non-blocking best effort."""
    # Give the ACK a moment to leave before we reboot
    try:
        time.sleep(0.25)
    except Exception:
        pass

    try:
        subprocess.Popen(
            ["/bin/systemctl", "reboot", "--no-wall"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        return
    except Exception:
        pass

    try:
        subprocess.Popen(
            ["/usr/bin/systemctl", "reboot", "--no-wall"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        return
    except Exception:
        pass

    try:
        subprocess.Popen(
            ["/sbin/reboot"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    except Exception:
        pass


def extract_command(payload: dict) -> dict:
    """
    Support both formats:
      - payload.command
      - payload.assignment.command
    """
    if not isinstance(payload, dict):
        return {}
    cmd = payload.get("command")
    if isinstance(cmd, dict) and cmd:
        return cmd
    assignment = payload.get("assignment")
    if isinstance(assignment, dict):
        cmd2 = assignment.get("command")
        if isinstance(cmd2, dict) and cmd2:
            return cmd2
    return {}


def maybe_handle_pending_command(server: str, device_uuid: str, payload: dict) -> None:
    cmd = extract_command(payload)
    if not isinstance(cmd, dict) or not cmd:
        return

    fp = command_fingerprint(cmd)
    if not fp:
        return

    last_fp = load_last_command_fingerprint()
    if fp == last_fp:
        return  # already processed

    ctype = str(cmd.get("type") or cmd.get("action") or "").lower().strip()
    if ctype == "reboot":
        # Mark as processed first to prevent reboot loops.
        save_last_command_fingerprint(fp)
        attempt_command_ack(server, device_uuid, cmd)
        trigger_reboot()
        return


    # Unknown command type: ignore (but do not record as processed)


def normalize_machine_id() -> str:
    mid = ""
    try:
        mid = MACHINE_ID_PATH.read_text(encoding="utf-8").strip()
    except Exception:
        mid = ""
    mid = (mid or "").strip().lower()
    if len(mid) >= 32:
        mid = mid[:32]
    mid = "".join([c for c in mid if c in "0123456789abcdef"])
    return mid


def is_http_url(u: str) -> bool:
    try:
        p = urlparse(u)
        return p.scheme in ("http", "https") and bool(p.netloc)
    except Exception:
        return False


def ensure_boot_logo_permissions():
    try:
        os.chmod(BOOT_LOGO_PATH, 0o644)
    except Exception:
        pass


def fetch_assignment(server: str, device_uuid: str) -> dict:
    # Use the public assignment endpoint (no bearer token needed).
    url = server.rstrip("/") + "/wp-json/callastream/v1/device/assignment"
    r = requests.get(url, params={"device_uuid": device_uuid}, timeout=15)
    r.raise_for_status()
    data = r.json()
    if not isinstance(data, dict):
        raise RuntimeError(f"assignment_bad_json: {data!r}")
    return data


def bootstrap(server: str, device_uuid: str) -> dict:
    url = server.rstrip("/") + "/wp-json/callastream/v1/device/bootstrap"
    # Send both keys for compatibility if server expects uuid vs device_uuid
    r = requests.post(url, json={"device_uuid": device_uuid, "uuid": device_uuid}, timeout=20)
    r.raise_for_status()
    data = r.json()
    if not isinstance(data, dict):
        raise RuntimeError(f"bootstrap_bad_json: {data!r}")
    return data


def maybe_sync_boot_logo(bootstrap_payload: dict):
    # If the server returns boot_logo_url, download it to /opt/callastream/boot_logo.png.
    url = bootstrap_payload.get("boot_logo_url")
    if not isinstance(url, str) or not url.strip():
        return
    url = url.strip()
    if not is_http_url(url):
        return

    cfg = read_json(DEVICE_JSON, {})
    if cfg.get("boot_logo_url") == url and BOOT_LOGO_PATH.exists():
        return

    r = requests.get(url, timeout=30, stream=True, headers={"Cache-Control": "no-cache", "Pragma": "no-cache"})
    r.raise_for_status()

    tmp = BOOT_LOGO_PATH.with_suffix(".png.tmp")
    with open(tmp, "wb") as f:
        for chunk in r.iter_content(chunk_size=1024 * 64):
            if chunk:
                f.write(chunk)
    os.replace(tmp, BOOT_LOGO_PATH)
    ensure_boot_logo_permissions()

    cfg["boot_logo_url"] = url
    write_json_atomic(DEVICE_JSON, cfg)

    kick_bootlogo_apply()


def build_state_from_assignment(device_uuid: str, payload: dict) -> dict:
    ok = payload.get("ok", True)
    claimed = bool(payload.get("claimed"))
    revision = payload.get("revision") or 0

    # Device-level settings (server sends this top-level)
    orientation = payload.get("orientation") or "landscape"
    if not isinstance(orientation, str):
        orientation = "landscape"
    orientation = orientation.strip().lower() or "landscape"
    if orientation not in ("landscape", "portrait-left", "portrait-right"):
        orientation = "landscape"

    state = {
        "device_uuid": device_uuid,
        "mode": "idle",
        "code": "",
        "content_type": "none",
        "revision": int(revision) if str(revision).isdigit() else 0,
        "orientation": orientation,
    }

    if not ok:
        return state

    if not claimed:
        code = (payload.get("activation_code") or "").strip()
        state["mode"] = "activation"
        state["code"] = code
        state["expires_at"] = payload.get("expires_at")
        return state

    assignment = payload.get("assignment")
    if not assignment:
        state["mode"] = "idle"
        return state

    ctype = (assignment.get("content_type") or "none").strip().lower()
    content = assignment.get("content") if isinstance(assignment.get("content"), dict) else {}
    arev = assignment.get("revision")
    if isinstance(arev, int):
        state["revision"] = arev

    if ctype == "slideshow":
        imgs = content.get("images") if isinstance(content.get("images"), list) else []
        urls = []
        for it in imgs:
            if isinstance(it, dict) and isinstance(it.get("url"), str) and it["url"].strip():
                urls.append(it["url"].strip())

        interval = content.get("interval", 8)
        try:
            interval = int(interval)
        except Exception:
            interval = 8
        if interval < 2:
            interval = 2

        bg = content.get("background") or content.get("bg") or "#000000"

        state.update({
            "mode": "play",
            "content_type": "slideshow",
            "image_urls": urls,
            "interval": interval,
            "bg": bg,
        })
        return state

    if ctype == "webpage":
        url = (content.get("url") or "").strip()
        state.update({
            "mode": "play",
            "content_type": "webpage",
            "url": url,
        })
        return state

    if ctype == "youtube":
        y = (content.get("youtube_url") or content.get("url") or "").strip()
        state.update({
            "mode": "play",
            "content_type": "youtube",
            "youtube_url": y,
        })
        return state

    return state


def build_wifi_setup_state(device_uuid: str) -> dict:
    """
    Local-only state used when the device is in Wi-Fi setup mode.
    This prevents the UI from showing a stale/invalid activation code while
    the AP captive portal is running.
    """
    return {
        "device_uuid": device_uuid,
        "mode": "wifi_setup",
        "code": "",
        "content_type": "setup",
        "revision": 0,
        "orientation": "landscape",
        "setup_image": "/setup.png",
    }


def main():
    cfg = read_json(DEVICE_JSON, {})
    server = (cfg.get("server") or DEFAULT_SERVER_URL).strip() or DEFAULT_SERVER_URL

    device_uuid = (cfg.get("device_uuid") or "").strip().lower()
    if not device_uuid:
        device_uuid = normalize_machine_id()
        if device_uuid:
            cfg["device_uuid"] = device_uuid
            cfg["server"] = server
            try:
                write_json_atomic(DEVICE_JSON, cfg)
            except Exception:
                pass

    if not device_uuid or len(device_uuid) != 32:
        write_json_atomic(STATE_JSON, {
            "device_uuid": device_uuid or "",
            "mode": "idle",
            "code": "",
            "content_type": "none",
            "revision": 0,
        })
        return

    last_bootstrap = 0

    while True:
        try:
            now = time.time()

            # If we're in Wi-Fi setup mode (AP/captive portal), always publish a
            # local-only state so the screen shows setup.png instead of a stale
            # activation code.
            # If we're forced into setup OR we cannot reach the CallaStream server, show Wi-Fi setup splash.
            # This covers:
            #  1) no saved Wi-Fi yet
            #  2) saved Wi-Fi but can't connect / no internet
            if WIFI_SETUP_FORCE_FILE.exists() or (not is_online()):
                write_json_atomic(STATE_JSON, build_wifi_setup_state(device_uuid))
                time.sleep(2)
                continue
            if (now - last_bootstrap) >= BOOTSTRAP_EVERY:
                try:
                    bp = bootstrap(server, device_uuid)
                    maybe_sync_boot_logo(bp)
                except Exception:
                    pass
                last_bootstrap = now

            payload = fetch_assignment(server, device_uuid)

            # ✅ Handle any pending device command (like reboot)
            maybe_handle_pending_command(server, device_uuid, payload)

            state = build_state_from_assignment(device_uuid, payload)
            write_json_atomic(STATE_JSON, state)

        except Exception:
            # If we're forced into Wi-Fi setup, ensure the UI shows the setup image.
            try:
                if WIFI_SETUP_FORCE_FILE.exists():
                    write_json_atomic(STATE_JSON, build_wifi_setup_state(device_uuid))
            except Exception:
                pass

        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
