#!/usr/bin/env bash
# Serve VNC unblock helper on http://127.0.0.1:8765/
# GET: docs/m2_vnc/unblock.html + /tmp/supabase-cli-login.url
# POST /drop: write PAT or CLI code to drop files (127.0.0.1 only; never logs secrets)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PAGE="$ROOT/docs/m2_vnc/unblock.html"
export M2_UNBLOCK_PAGE="$PAGE"
python3 - <<'PY'
import json
import os
import re
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs

PAGE = Path(os.environ["M2_UNBLOCK_PAGE"]).resolve()
URL_FILE = Path("/tmp/supabase-cli-login.url")
RAW_TOKEN = Path("/tmp/supabase-access-token")
ENV_FILE = Path("/tmp/destiny-m2.env")
CLI_CODE = Path("/tmp/supabase-cli-code")
WAKE_FILE = Path("/tmp/m2-cred-wake")
MEDIA_PACK = Path(os.environ.get("M2_DASHBOARD_MEDIA_PACK", "/tmp/m2-dashboard-media-pack.tar"))

PAT_RE = re.compile(r"^sbp_[A-Za-z0-9_-]{20,}$|^[A-Za-z0-9._-]{20,}$")
CODE_RE = re.compile(r"^[A-Za-z0-9]{4,32}$")


def _write_secret(path: Path, text: str) -> None:
    path.write_text(text.strip() + "\n", encoding="utf-8")
    os.chmod(path, 0o600)


def _wake_watchers() -> None:
    try:
        WAKE_FILE.write_text("1\n", encoding="utf-8")
    except OSError:
        pass


class H(SimpleHTTPRequestHandler):
    def _json(self, code: int, payload: dict) -> None:
        data = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path in ("/", "/index.html", "/m2-unblock.html"):
            data = PAGE.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        if self.path.startswith("/status"):
            catalog_code = None
            try:
                import urllib.request

                req = urllib.request.Request(
                    "https://xchddfpfzrzhlbbmyhyn.supabase.co/storage/v1/object/public/destiny-media/inventory/catalog.json",
                    method="HEAD",
                )
                with urllib.request.urlopen(req, timeout=8) as resp:
                    catalog_code = int(resp.status)
            except Exception as exc:  # noqa: BLE001 — status probe only
                catalog_code = getattr(exc, "code", None)
                if catalog_code is None:
                    catalog_code = -1
            apply_ready = Path("/tmp/m2-apply-ready").exists()
            apply_done = Path("/tmp/m2-watch-apply.done").exists()
            self._json(
                200,
                {
                    "has_raw_token": RAW_TOKEN.exists(),
                    "has_env_file": ENV_FILE.exists(),
                    "has_cli_code": CLI_CODE.exists(),
                    "has_cli_url": URL_FILE.exists(),
                    "has_cli_access_token": Path.home().joinpath(".supabase/access-token").exists(),
                    "catalog_http": catalog_code,
                    "apply_ready": apply_ready,
                    "apply_done": apply_done,
                    "milestone_live": catalog_code == 200,
                    "media_pack_ready": MEDIA_PACK.is_file(),
                    "media_live_signal": Path("/tmp/m2-media-live").exists(),
                },
            )
            return
        if self.path.startswith("/m2-dashboard-media-pack.tar"):
            if not MEDIA_PACK.is_file():
                self.send_error(404, "media pack not built — run scripts/m2_build_dashboard_media_pack.sh")
                return
            data = MEDIA_PACK.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "application/x-tar")
            self.send_header(
                "Content-Disposition",
                'attachment; filename="m2-dashboard-media-pack.tar"',
            )
            self.send_header("Cache-Control", "no-store")
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

    def do_POST(self):
        if self.path not in ("/drop", "/drop/"):
            self.send_error(404)
            return
        length = int(self.headers.get("Content-Length", "0") or "0")
        if length <= 0 or length > 8192:
            self._json(400, {"ok": False, "error": "bad body length"})
            return
        raw = self.rfile.read(length).decode("utf-8", errors="replace")
        ctype = (self.headers.get("Content-Type") or "").split(";")[0].strip().lower()
        if ctype == "application/json":
            try:
                body = json.loads(raw)
            except json.JSONDecodeError:
                self._json(400, {"ok": False, "error": "invalid json"})
                return
        else:
            qs = parse_qs(raw, keep_blank_values=False)
            body = {k: (v[0] if v else "") for k, v in qs.items()}

        kind = str(body.get("kind") or "").strip().lower()
        value = str(body.get("value") or "").strip()
        if not value:
            self._json(400, {"ok": False, "error": "empty value"})
            return

        try:
            if kind in ("pat", "token", "access_token"):
                # Strip accidental KEY= prefix from paste
                if value.startswith("SUPABASE_ACCESS_TOKEN="):
                    value = value.split("=", 1)[1].strip()
                if not PAT_RE.match(value):
                    self._json(400, {"ok": False, "error": "token shape rejected"})
                    return
                _write_secret(RAW_TOKEN, value)
                _wake_watchers()
                self._json(200, {"ok": True, "wrote": "raw_token"})
                return
            if kind in ("code", "cli_code", "verification_code"):
                value = re.sub(r"\s+", "", value)
                if not CODE_RE.match(value):
                    self._json(400, {"ok": False, "error": "code shape rejected"})
                    return
                _write_secret(CLI_CODE, value)
                _wake_watchers()
                self._json(200, {"ok": True, "wrote": "cli_code"})
                return
            self._json(400, {"ok": False, "error": "unknown kind"})
        except OSError:
            self._json(500, {"ok": False, "error": "write failed"})

    def log_message(self, fmt, *args):
        # Never log request bodies (may contain secrets). Path-only is fine.
        try:
            msg = fmt % args
        except Exception:
            msg = fmt
        if "drop" in str(msg):
            print("POST /drop (body redacted)", flush=True)
            return
        # silence routine GETs


print("M2 unblock helper: http://127.0.0.1:8765/", flush=True)
ThreadingHTTPServer(("127.0.0.1", 8765), H).serve_forever()
PY
