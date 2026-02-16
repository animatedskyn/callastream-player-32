#!/usr/bin/env python3
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs

CREDS_PATH = "/opt/callastream/setup/CREDS.json"

FORM_HTML = """<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>CallaStream WiFi Setup</title>
  <style>
    body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif;background:#0b1b3a;color:#fff;margin:0;padding:24px}
    .card{max-width:520px;margin:0 auto;background:#102a5a;border-radius:16px;padding:22px;box-shadow:0 10px 30px rgba(0,0,0,.35)}
    h1{margin:0 0 6px;font-size:22px}
    p{margin:0 0 16px;opacity:.9}
    label{display:block;margin:12px 0 6px;font-weight:600}
    input{width:100%;padding:12px;border-radius:10px;border:0;font-size:16px}
    button{margin-top:16px;width:100%;padding:12px;border-radius:10px;border:0;background:#2d7cff;color:#fff;font-size:16px;font-weight:700}
    .small{font-size:13px;opacity:.85;margin-top:12px}
  </style>
</head>
<body>
  <div class="card">
    <h1>Connect your CallaStream device to WiFi</h1>
    <p>Enter your WiFi name and password, then press Save.</p>
    <form method="POST">
      <label>WiFi Network Name (SSID)</label>
      <input name="ssid" required>
      <label>Password</label>
      <input name="psk" type="password">
      <button type="submit">Save & Connect</button>
    </form>
    <div class="small">The device will reboot after saving.</div>
  </div>
</body>
</html>
"""

OK_HTML = """<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Saved</title></head>
<body style="background:#0f3d2e;color:#fff;font-family:sans-serif;padding:24px">
<h1>Saved!</h1>
<p>Connecting to WiFi and rebooting…</p>
</body></html>
"""

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(FORM_HTML.encode())

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0") or "0")
        raw = self.rfile.read(length).decode(errors="ignore")
        data = parse_qs(raw)
        ssid = (data.get("ssid") or [""])[0]
        psk  = (data.get("psk") or [""])[0]
        if not ssid:
            self.send_error(400, "Missing SSID")
            return
        with open(CREDS_PATH, "w") as f:
            json.dump({"ssid": ssid, "psk": psk}, f)
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(OK_HTML.encode())

def main():
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()

if __name__ == "__main__":
    main()
