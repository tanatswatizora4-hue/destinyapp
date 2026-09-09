#!/usr/bin/env bash
# Serve VNC unblock helper on http://127.0.0.1:8765/
# Serves docs/m2_vnc/unblock.html and /tmp/supabase-cli-login.url
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PAGE="$ROOT/docs/m2_vnc/unblock.html"
export M2_UNBLOCK_PAGE="$PAGE"
python3 - <<'PY'
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PAGE = Path(os.environ["M2_UNBLOCK_PAGE"]).resolve()
URL_FILE = Path("/tmp/supabase-cli-login.url")

class H(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/", "/index.html", "/m2-unblock.html"):
            data = PAGE.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        if self.path.startswith("/supabase-cli-login.url"):
            if not URL_FILE.exists():
                self.send_error(404, "CLI login URL not ready")
                return
            data = URL_FILE.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        self.send_error(404)

    def log_message(self, fmt, *args):
        return

print("M2 unblock helper: http://127.0.0.1:8765/", flush=True)
ThreadingHTTPServer(("127.0.0.1", 8765), H).serve_forever()
PY
