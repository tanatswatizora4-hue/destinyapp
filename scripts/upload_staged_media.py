#!/usr/bin/env python3
"""Upload pre-staged inventory media into destiny-media Storage.

Requires:
  SUPABASE_SERVICE_ROLE_KEY
  SUPABASE_URL (default destiny-os)

Reads:
  supabase/seed/media_manifest.json
  /tmp/destiny-media-staging/...  (or extracts .m2_staging tarball)
  supabase/seed/destiny_inventory_catalog.json → inventory/catalog.json

Updates DB image storage_path / primary_image_path where legacy_url matches.
"""

from __future__ import annotations

import json
import os
import sys
import tarfile
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "supabase" / "seed" / "media_manifest.json"
CATALOG = ROOT / "supabase" / "seed" / "destiny_inventory_catalog.json"
MISSING = ROOT / "docs" / "m2_missing_media.json"
STAGING = Path(os.environ.get("DESTINY_MEDIA_STAGING", "/tmp/destiny-media-staging"))
TARBALLS = [
    ROOT / "supabase" / "seed" / "destiny-inventory-media-staged.tar",
    ROOT / ".m2_staging" / "destiny-inventory-media-staged.tar",
    Path("/tmp/destiny-inventory-media-staged.tar"),
]

SUPABASE_URL = os.environ.get(
    "SUPABASE_URL", "https://xchddfpfzrzhlbbmyhyn.supabase.co"
).rstrip("/")
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
UPLOAD_CATALOG = os.environ.get("DESTINY_UPLOAD_CATALOG", "1") == "1"
CATALOG_ONLY = os.environ.get("DESTINY_CATALOG_ONLY", "0") == "1"


def die(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def headers() -> dict:
    return {
        "apikey": SERVICE_KEY,
        "Authorization": f"Bearer {SERVICE_KEY}",
    }


def ensure_staging() -> None:
    if STAGING.is_dir() and any(p.is_file() for p in STAGING.rglob("*")):
        print(f"Using existing staging at {STAGING}")
        return
    for tarball in TARBALLS:
        if not tarball.is_file():
            continue
        print(f"Extracting {tarball} → {STAGING}")
        STAGING.mkdir(parents=True, exist_ok=True)
        # Tarball members are kind/id/filename (tours/39/primary.jpg), not a wrapper dir.
        with tarfile.open(tarball, "r") as tar:
            tar.extractall(path=STAGING)
        if not any(p.is_file() for p in STAGING.rglob("*")):
            die(f"extract produced no files under {STAGING}")
        return
    die(
        f"No staging at {STAGING} and no tarball in "
        f"{[str(p) for p in TARBALLS]}. Run media staging first."
    )


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
        ".json": "application/json",
    }.get(ext, "application/octet-stream")


def resolve_local(item: dict) -> Path:
    """Prefer manifest local path; fall back to staging object key."""
    local = Path(item["local"])
    if local.exists() and local.stat().st_size > 0:
        return local
    # Manifest paths are absolute /tmp/...; remap if staging root differs.
    object_path = item["object_path"]
    assert object_path.startswith("destiny-media/")
    rel = object_path[len("destiny-media/") :]
    alt = STAGING / rel
    return alt


def main() -> None:
    if not SERVICE_KEY:
        die("SUPABASE_SERVICE_ROLE_KEY required")
    if "xchddfpfzrzhlbbmyhyn" not in SUPABASE_URL:
        die(f"refusing non-destiny-os URL: {SUPABASE_URL}")

    if not CATALOG_ONLY:
        ensure_staging()

    items = json.loads(MANIFEST.read_text(encoding="utf-8"))
    uploaded = 0
    missing = []
    if CATALOG_ONLY:
        print("DESTINY_CATALOG_ONLY=1 — skipping image uploads")
        items = []
    for item in items:
        local = resolve_local(item)
        if not local.exists() or local.stat().st_size == 0:
            missing.append({**item, "status": "missing_local"})
            print(f"missing local {item['object_path']}")
            continue
        try:
            upload(item["object_path"], local.read_bytes(), guess_ctype(local))
            uploaded += 1
            print(f"uploaded {item['object_path']}")
            kind = item["kind"]
            try:
                legacy_q = urllib.parse.quote(item["legacy"], safe="")
                if kind == "tours":
                    patch(
                        "tour_images",
                        f"legacy_url=eq.{legacy_q}",
                        {"storage_path": item["object_path"]},
                    )
                    patch(
                        "tours",
                        f"primary_image_path=eq.{legacy_q}",
                        {"primary_image_path": item["object_path"]},
                    )
                elif kind == "stays":
                    patch(
                        "stay_images",
                        f"legacy_url=eq.{legacy_q}",
                        {"storage_path": item["object_path"]},
                    )
                    patch(
                        "stays",
                        f"primary_image_path=eq.{legacy_q}",
                        {"primary_image_path": item["object_path"]},
                    )
                elif kind == "vehicles":
                    patch(
                        "vehicle_images",
                        f"legacy_url=eq.{legacy_q}",
                        {"storage_path": item["object_path"]},
                    )
                    patch(
                        "vehicles",
                        f"primary_image_path=eq.{legacy_q}",
                        {"primary_image_path": item["object_path"]},
                    )
                elif kind == "awards":
                    patch(
                        "award_images",
                        f"legacy_url=eq.{legacy_q}",
                        {"storage_path": item["object_path"]},
                    )
                    patch(
                        "awards",
                        f"primary_image_path=eq.{legacy_q}",
                        {"primary_image_path": item["object_path"]},
                    )
            except Exception as exc:  # noqa: BLE001
                print(f"  db patch skipped: {exc}")
        except Exception as exc:  # noqa: BLE001
            print(f"upload fail {item['object_path']}: {exc}")
            missing.append({**item, "error": str(exc)})

    if UPLOAD_CATALOG:
        if not CATALOG.is_file():
            die(f"catalog missing: {CATALOG}")
        upload(
            "destiny-media/inventory/catalog.json",
            CATALOG.read_bytes(),
            "application/json",
        )
        print("uploaded destiny-media/inventory/catalog.json")

    # Keep documented legacy HTTP 404s; append upload-time local misses.
    documented: list[dict] = []
    if MISSING.is_file():
        try:
            prior = json.loads(MISSING.read_text(encoding="utf-8"))
            if isinstance(prior, list):
                documented = [m for m in prior if isinstance(m, dict)]
        except json.JSONDecodeError:
            documented = []
    by_path = {
        m.get("object_path"): m
        for m in documented
        if m.get("object_path")
    }
    for m in missing:
        key = m.get("object_path")
        if key:
            by_path[key] = m
    MISSING.write_text(
        json.dumps(list(by_path.values()), indent=2), encoding="utf-8"
    )
    print(f"uploaded={uploaded} missing_local={len(missing)}")


if __name__ == "__main__":
    main()
