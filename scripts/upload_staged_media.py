#!/usr/bin/env python3
"""Upload pre-staged inventory media from /tmp/destiny-media-staging into destiny-media.

Requires:
  SUPABASE_SERVICE_ROLE_KEY
  SUPABASE_URL (default destiny-os)

Reads:
  supabase/seed/media_manifest.json
  /tmp/destiny-media-staging/...

Updates DB image storage_path / primary_image_path where legacy_url matches.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "supabase" / "seed" / "media_manifest.json"
MISSING = ROOT / "docs" / "m2_missing_media.json"

SUPABASE_URL = os.environ.get(
    "SUPABASE_URL", "https://xchddfpfzrzhlbbmyhyn.supabase.co"
).rstrip("/")
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()


def die(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def headers() -> dict:
    return {
        "apikey": SERVICE_KEY,
        "Authorization": f"Bearer {SERVICE_KEY}",
    }


def upload(object_path: str, content: bytes, content_type: str) -> None:
    assert object_path.startswith("destiny-media/")
    key = object_path[len("destiny-media/") :]
    url = f"{SUPABASE_URL}/storage/v1/object/destiny-media/{key}"
    req = urllib.request.Request(url, data=content, method="POST")
    for k, v in headers().items():
        req.add_header(k, v)
    req.add_header("Content-Type", content_type)
    req.add_header("x-upsert", "true")
    with urllib.request.urlopen(req, timeout=120):
        return


def patch(table: str, match_query: str, body: dict) -> None:
    url = f"{SUPABASE_URL}/rest/v1/{table}?{match_query}"
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, method="PATCH")
    for k, v in headers().items():
        req.add_header(k, v)
    req.add_header("Content-Type", "application/json")
    req.add_header("Prefer", "return=minimal")
    with urllib.request.urlopen(req, timeout=60):
        return


def guess_ctype(path: Path) -> str:
    ext = path.suffix.lower()
    return {
        ".webp": "image/webp",
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".gif": "image/gif",
    }.get(ext, "application/octet-stream")


def main() -> None:
    if not SERVICE_KEY:
        die("SUPABASE_SERVICE_ROLE_KEY required")
    if "xchddfpfzrzhlbbmyhyn" not in SUPABASE_URL:
        die(f"refusing non-destiny-os URL: {SUPABASE_URL}")
    items = json.loads(MANIFEST.read_text(encoding="utf-8"))
    uploaded = 0
    missing = []
    for item in items:
        local = Path(item["local"])
        if not local.exists() or local.stat().st_size == 0:
            missing.append(item)
            print(f"missing local {item['object_path']}")
            continue
        try:
            upload(item["object_path"], local.read_bytes(), guess_ctype(local))
            uploaded += 1
            print(f"uploaded {item['object_path']}")
            # Best-effort DB path updates (tables must exist)
            legacy = item["legacy"].replace("'", "''")
            kind = item["kind"]
            try:
                if kind == "tours":
                    patch(
                        "tour_images",
                        f"legacy_url=eq.{urllib.parse.quote(item['legacy'], safe='')}",
                        {"storage_path": item["object_path"]},
                    )
                elif kind == "stays":
                    patch(
                        "stay_images",
                        f"legacy_url=eq.{urllib.parse.quote(item['legacy'], safe='')}",
                        {"storage_path": item["object_path"]},
                    )
                elif kind == "vehicles":
                    patch(
                        "vehicle_images",
                        f"legacy_url=eq.{urllib.parse.quote(item['legacy'], safe='')}",
                        {"storage_path": item["object_path"]},
                    )
                elif kind == "awards":
                    patch(
                        "award_images",
                        f"legacy_url=eq.{urllib.parse.quote(item['legacy'], safe='')}",
                        {"storage_path": item["object_path"]},
                    )
            except Exception as exc:  # noqa: BLE001
                print(f"  db patch skipped: {exc}")
        except Exception as exc:  # noqa: BLE001
            print(f"upload fail {item['object_path']}: {exc}")
            missing.append({**item, "error": str(exc)})

    MISSING.write_text(json.dumps(missing, indent=2), encoding="utf-8")
    print(f"uploaded={uploaded} missing={len(missing)}")


if __name__ == "__main__":
    import urllib.parse

    main()
