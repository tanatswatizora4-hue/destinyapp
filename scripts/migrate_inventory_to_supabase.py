#!/usr/bin/env python3
"""Migrate Destiny inventory from bymapara PHP API → Supabase PostgREST.

Required env (never commit):
  SUPABASE_URL=https://xchddfpfzrzhlbbmyhyn.supabase.co
  SUPABASE_SERVICE_ROLE_KEY=...

Optional:
  DESTINY_MIGRATE_MEDIA=1  # download legacy uploads into destiny-media bucket
  LEGACY_API=https://bymapara.com/destiny_api.php

Idempotent on legacy_id (upsert).
"""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "docs" / "m2_data_migration_report.md"

SUPABASE_URL = os.environ.get(
    "SUPABASE_URL", "https://xchddfpfzrzhlbbmyhyn.supabase.co"
).rstrip("/")
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
LEGACY_API = os.environ.get(
    "LEGACY_API", "https://bymapara.com/destiny_api.php"
)
MIGRATE_MEDIA = os.environ.get("DESTINY_MIGRATE_MEDIA", "0") == "1"


def die(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def http_json(url: str, *, method: str = "GET", headers: dict | None = None, body: Any = None) -> Any:
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, method=method)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=60) as resp:
        raw = resp.read().decode("utf-8")
        return json.loads(raw) if raw else None


def legacy_action(action: str) -> list[dict]:
    url = f"{LEGACY_API}?action={urllib.parse.quote(action)}"
    payload = http_json(url)
    if not isinstance(payload, dict) or payload.get("status") != "success":
        die(f"Legacy {action} failed: {payload}")
    data = payload.get("data") or []
    if not isinstance(data, list):
        die(f"Legacy {action} data is not a list")
    return data


def sb_headers() -> dict:
    return {
        "apikey": SERVICE_KEY,
        "Authorization": f"Bearer {SERVICE_KEY}",
        "Prefer": "resolution=merge-duplicates,return=representation",
    }


def upsert(table: str, rows: list[dict], on_conflict: str) -> list[dict]:
    if not rows:
        return []
    url = f"{SUPABASE_URL}/rest/v1/{table}?on_conflict={on_conflict}"
    result = http_json(url, method="POST", headers=sb_headers(), body=rows)
    return result or []


def parse_json_list(raw: Any) -> list:
    if raw is None:
        return []
    if isinstance(raw, list):
        return raw
    if isinstance(raw, str):
        try:
            val = json.loads(raw or "[]")
            return val if isinstance(val, list) else []
        except json.JSONDecodeError:
            return []
    return []


def safe_name(value: str) -> str:
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9._-]+", "-", value)
    return value.strip("-")[:80] or "file"


def media_ref(kind: str, legacy_id: int, filename: str) -> str:
    return f"destiny-media/{kind}/{legacy_id}/{filename}"


def upload_storage(object_path: str, content: bytes, content_type: str) -> None:
    # object_path like destiny-media/tours/1/primary.jpg → bucket destiny-media, key tours/1/...
    assert object_path.startswith("destiny-media/")
    key = object_path[len("destiny-media/") :]
    url = f"{SUPABASE_URL}/storage/v1/object/destiny-media/{key}"
    req = urllib.request.Request(url, data=content, method="POST")
    req.add_header("apikey", SERVICE_KEY)
    req.add_header("Authorization", f"Bearer {SERVICE_KEY}")
    req.add_header("Content-Type", content_type)
    req.add_header("x-upsert", "true")
    with urllib.request.urlopen(req, timeout=120):
        return


def download(url: str) -> tuple[bytes, str] | None:
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=60) as resp:
            ctype = resp.headers.get("Content-Type", "application/octet-stream")
            return resp.read(), ctype
    except Exception as exc:  # noqa: BLE001
        print(f"  media miss: {url} ({exc})")
        return None


def resolve_legacy_url(path: str) -> str:
    path = path.strip()
    if path.startswith("http://") or path.startswith("https://"):
        parsed = urllib.parse.urlsplit(path)
        encoded_path = urllib.parse.quote(parsed.path)
        return urllib.parse.urlunsplit(
            (parsed.scheme, parsed.netloc, encoded_path, parsed.query, parsed.fragment)
        )
    if path.startswith("/"):
        path = path[1:]
    encoded = "/".join(urllib.parse.quote(seg) for seg in path.split("/"))
    return f"https://bymapara.com/{encoded}"


def migrate_images(
    kind: str,
    legacy_id: int,
    image_urls: list[str],
    stats: dict,
) -> tuple[str | None, list[dict]]:
    """Returns primary path + image rows (storage_path may still be legacy)."""
    rows: list[dict] = []
    primary: str | None = None
    for idx, raw in enumerate(image_urls):
        legacy = raw if isinstance(raw, str) else str(raw)
        storage_path = legacy
        if MIGRATE_MEDIA and legacy:
            url = resolve_legacy_url(legacy)
            downloaded = download(url)
            if downloaded:
                content, ctype = downloaded
                ext = ".webp" if "webp" in ctype else ".jpg"
                if "png" in ctype:
                    ext = ".png"
                elif "jpeg" in ctype or "jpg" in ctype:
                    ext = ".jpg"
                fname = "primary" + ext if idx == 0 else f"gallery-{idx:02d}{ext}"
                object_path = media_ref(kind, legacy_id, fname)
                try:
                    upload_storage(object_path, content, ctype.split(";")[0])
                    storage_path = object_path
                    stats["media_uploaded"] += 1
                except Exception as exc:  # noqa: BLE001
                    print(f"  upload failed {object_path}: {exc}")
                    stats["media_failed"] += 1
            else:
                stats["media_missing"] += 1
        if idx == 0:
            primary = storage_path
        rows.append(
            {
                "storage_path": storage_path,
                "legacy_url": legacy,
                "sort_order": idx,
            }
        )
    return primary, rows


def main() -> None:
    if not SERVICE_KEY:
        die(
            "SUPABASE_SERVICE_ROLE_KEY is required to migrate. "
            "Export it in the environment (never commit)."
        )

    report = {
        "tours": {"source": 0, "upserted": 0, "skipped": 0},
        "stays": {"source": 0, "upserted": 0, "skipped": 0},
        "vehicles": {"source": 0, "upserted": 0, "skipped": 0},
        "awards": {"source": 0, "upserted": 0, "skipped": 0},
        "media_uploaded": 0,
        "media_failed": 0,
        "media_missing": 0,
        "malformed": [],
    }

    # --- Tours ---
    tours = legacy_action("get_tours")
    report["tours"]["source"] = len(tours)
    for item in tours:
        try:
            legacy_id = int(item["id"])
            images = parse_json_list(item.get("image_urls_json"))
            primary, image_rows = migrate_images("tours", legacy_id, images, report)
            upserted = upsert(
                "tours",
                [
                    {
                        "legacy_id": legacy_id,
                        "title": item.get("title") or "No Title",
                        "description": item.get("description") or "",
                        "price": float(item.get("price") or 0),
                        "duration": item.get("duration") or "",
                        "is_featured": str(item.get("is_featured")) in ("1", "true", "True"),
                        "is_published": True,
                        "primary_image_path": primary,
                    }
                ],
                "legacy_id",
            )
            tour_id = upserted[0]["id"]
            # replace children
            http_json(
                f"{SUPABASE_URL}/rest/v1/tour_images?tour_id=eq.{tour_id}",
                method="DELETE",
                headers=sb_headers(),
            )
            http_json(
                f"{SUPABASE_URL}/rest/v1/tour_amenities?tour_id=eq.{tour_id}",
                method="DELETE",
                headers=sb_headers(),
            )
            http_json(
                f"{SUPABASE_URL}/rest/v1/tour_itinerary_items?tour_id=eq.{tour_id}",
                method="DELETE",
                headers=sb_headers(),
            )
            if image_rows:
                upsert(
                    "tour_images",
                    [{"tour_id": tour_id, **row} for row in image_rows],
                    "id",
                )
            amenities = parse_json_list(item.get("amenities_json"))
            if amenities:
                http_json(
                    f"{SUPABASE_URL}/rest/v1/tour_amenities",
                    method="POST",
                    headers=sb_headers(),
                    body=[
                        {
                            "tour_id": tour_id,
                            "name": a.get("name") or "",
                            "included": bool(a.get("included", True)),
                            "sort_order": i,
                        }
                        for i, a in enumerate(amenities)
                        if isinstance(a, dict)
                    ],
                )
            itinerary = parse_json_list(item.get("itinerary_json"))
            if itinerary:
                http_json(
                    f"{SUPABASE_URL}/rest/v1/tour_itinerary_items",
                    method="POST",
                    headers=sb_headers(),
                    body=[
                        {
                            "tour_id": tour_id,
                            "date_label": a.get("date") or "",
                            "location": a.get("location") or "",
                            "activity": a.get("activity") or "",
                            "description": a.get("description") or "",
                            "sort_order": i,
                        }
                        for i, a in enumerate(itinerary)
                        if isinstance(a, dict)
                    ],
                )
            report["tours"]["upserted"] += 1
            print(f"tour legacy_id={legacy_id} ok")
        except Exception as exc:  # noqa: BLE001
            report["tours"]["skipped"] += 1
            report["malformed"].append(f"tour {item.get('id')}: {exc}")
            print(f"tour fail {item.get('id')}: {exc}")

    # --- Stays ---
    stays = legacy_action("get_accommodations")
    report["stays"]["source"] = len(stays)
    for item in stays:
        try:
            legacy_id = int(item["id"])
            images = parse_json_list(item.get("image_urls_json"))
            primary, image_rows = migrate_images("stays", legacy_id, images, report)
            upserted = upsert(
                "stays",
                [
                    {
                        "legacy_id": legacy_id,
                        "name": item.get("name") or "No Name",
                        "type": item.get("type") or "",
                        "description": item.get("description") or "",
                        "address": item.get("address") or "",
                        "city": item.get("city") or "",
                        "country": item.get("country") or "",
                        "is_featured": str(item.get("is_featured")) in ("1", "true", "True"),
                        "is_published": True,
                        "primary_image_path": primary,
                    }
                ],
                "legacy_id",
            )
            stay_id = upserted[0]["id"]
            for child in ("stay_images", "stay_rooms", "stay_amenities"):
                http_json(
                    f"{SUPABASE_URL}/rest/v1/{child}?stay_id=eq.{stay_id}",
                    method="DELETE",
                    headers=sb_headers(),
                )
            if image_rows:
                http_json(
                    f"{SUPABASE_URL}/rest/v1/stay_images",
                    method="POST",
                    headers=sb_headers(),
                    body=[{"stay_id": stay_id, **row} for row in image_rows],
                )
            rooms = parse_json_list(item.get("room_types_json"))
            if rooms:
                http_json(
                    f"{SUPABASE_URL}/rest/v1/stay_rooms",
                    method="POST",
                    headers=sb_headers(),
                    body=[
                        {
                            "stay_id": stay_id,
                            "name": r.get("name") or "Room",
                            "price": float(r.get("price") or 0),
                            "capacity": int(r.get("capacity") or 0),
                            "sort_order": i,
                        }
                        for i, r in enumerate(rooms)
                        if isinstance(r, dict)
                    ],
                )
            amenities = parse_json_list(item.get("amenities_json"))
            if amenities:
                http_json(
                    f"{SUPABASE_URL}/rest/v1/stay_amenities",
                    method="POST",
                    headers=sb_headers(),
                    body=[
                        {
                            "stay_id": stay_id,
                            "name": a.get("name") or "",
                            "included": bool(a.get("included", True)),
                            "sort_order": i,
                        }
                        for i, a in enumerate(amenities)
                        if isinstance(a, dict)
                    ],
                )
            report["stays"]["upserted"] += 1
            print(f"stay legacy_id={legacy_id} ok")
        except Exception as exc:  # noqa: BLE001
            report["stays"]["skipped"] += 1
            report["malformed"].append(f"stay {item.get('id')}: {exc}")
            print(f"stay fail {item.get('id')}: {exc}")

    # --- Vehicles ---
    vehicles = legacy_action("get_vehicles")
    report["vehicles"]["source"] = len(vehicles)
    for item in vehicles:
        try:
            legacy_id = int(item["id"])
            images = parse_json_list(item.get("image_urls_json"))
            primary, image_rows = migrate_images("vehicles", legacy_id, images, report)
            upserted = upsert(
                "vehicles",
                [
                    {
                        "legacy_id": legacy_id,
                        "make": item.get("make") or "",
                        "model": item.get("model") or "",
                        "year": int(item.get("year") or 0),
                        "type": item.get("type") or "",
                        "price_per_day": float(item.get("price_per_day") or 0),
                        "address": item.get("address") or "",
                        "city": item.get("city") or "",
                        "country": item.get("country") or "",
                        "is_featured": str(item.get("is_featured")) in ("1", "true", "True"),
                        "is_published": True,
                        "primary_image_path": primary,
                    }
                ],
                "legacy_id",
            )
            vehicle_id = upserted[0]["id"]
            for child in ("vehicle_images", "vehicle_features"):
                http_json(
                    f"{SUPABASE_URL}/rest/v1/{child}?vehicle_id=eq.{vehicle_id}",
                    method="DELETE",
                    headers=sb_headers(),
                )
            if image_rows:
                http_json(
                    f"{SUPABASE_URL}/rest/v1/vehicle_images",
                    method="POST",
                    headers=sb_headers(),
                    body=[{"vehicle_id": vehicle_id, **row} for row in image_rows],
                )
            features = parse_json_list(item.get("amenities_json"))
            if features:
                http_json(
                    f"{SUPABASE_URL}/rest/v1/vehicle_features",
                    method="POST",
                    headers=sb_headers(),
                    body=[
                        {
                            "vehicle_id": vehicle_id,
                            "name": a.get("name") or "",
                            "included": bool(a.get("included", True)),
                            "sort_order": i,
                        }
                        for i, a in enumerate(features)
                        if isinstance(a, dict)
                    ],
                )
            report["vehicles"]["upserted"] += 1
            print(f"vehicle legacy_id={legacy_id} ok")
        except Exception as exc:  # noqa: BLE001
            report["vehicles"]["skipped"] += 1
            report["malformed"].append(f"vehicle {item.get('id')}: {exc}")
            print(f"vehicle fail {item.get('id')}: {exc}")

    # --- Awards ---
    try:
        awards = legacy_action("get_awards")
    except SystemExit:
        awards = []
    report["awards"]["source"] = len(awards)
    for item in awards:
        try:
            legacy_id = int(item["id"])
            images = parse_json_list(item.get("image_url_json") or item.get("image_urls_json"))
            primary, image_rows = migrate_images("awards", legacy_id, images, report)
            upserted = upsert(
                "awards",
                [
                    {
                        "legacy_id": legacy_id,
                        "name": item.get("name") or "No Name",
                        "description": item.get("description") or "",
                        "year": int(item.get("year") or 0),
                        "is_published": True,
                        "primary_image_path": primary,
                    }
                ],
                "legacy_id",
            )
            award_id = upserted[0]["id"]
            http_json(
                f"{SUPABASE_URL}/rest/v1/award_images?award_id=eq.{award_id}",
                method="DELETE",
                headers=sb_headers(),
            )
            if image_rows:
                http_json(
                    f"{SUPABASE_URL}/rest/v1/award_images",
                    method="POST",
                    headers=sb_headers(),
                    body=[{"award_id": award_id, **row} for row in image_rows],
                )
            report["awards"]["upserted"] += 1
            print(f"award legacy_id={legacy_id} ok")
        except Exception as exc:  # noqa: BLE001
            report["awards"]["skipped"] += 1
            report["malformed"].append(f"award {item.get('id')}: {exc}")
            print(f"award fail {item.get('id')}: {exc}")

    lines = [
        "# M2 data migration report",
        "",
        f"Supabase: `{SUPABASE_URL}`",
        f"Media copy enabled: `{MIGRATE_MEDIA}`",
        "",
        "| Entity | Source | Upserted | Skipped |",
        "|---|---:|---:|---:|",
        f"| Tours | {report['tours']['source']} | {report['tours']['upserted']} | {report['tours']['skipped']} |",
        f"| Stays | {report['stays']['source']} | {report['stays']['upserted']} | {report['stays']['skipped']} |",
        f"| Vehicles | {report['vehicles']['source']} | {report['vehicles']['upserted']} | {report['vehicles']['skipped']} |",
        f"| Awards | {report['awards']['source']} | {report['awards']['upserted']} | {report['awards']['skipped']} |",
        "",
        f"Media uploaded: **{report['media_uploaded']}**",
        f"Media failed: **{report['media_failed']}**",
        f"Media missing: **{report['media_missing']}**",
        "",
        "## Malformed / skipped",
        "",
    ]
    if report["malformed"]:
        lines.extend(f"- {m}" for m in report["malformed"])
    else:
        lines.append("- none")
    lines.append("")
    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {REPORT}")


if __name__ == "__main__":
    main()
