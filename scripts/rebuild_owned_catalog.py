#!/usr/bin/env python3
"""Rebuild supabase/seed/destiny_inventory_catalog.json from snapshot + manifest.

Does not touch assets/data until media is live (use --sync-assets after upload).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SNAPSHOT = ROOT / "supabase" / "seed" / "legacy_inventory_snapshot.json"
MANIFEST = ROOT / "supabase" / "seed" / "media_manifest.json"
OUT = ROOT / "supabase" / "seed" / "destiny_inventory_catalog.json"
ASSET = ROOT / "assets" / "data" / "destiny_inventory_catalog.json"
LEGACY_MAP = ROOT / "assets" / "data" / "destiny_media_legacy_map.json"


def parse_json_list(raw):
    if raw is None:
        return []
    if isinstance(raw, list):
        return raw
    if isinstance(raw, str):
        text = raw.strip()
        if not text:
            return []
        try:
            val = json.loads(text)
            if isinstance(val, list):
                return val
            if isinstance(val, str) and val.strip():
                return [val.strip()]
            return []
        except json.JSONDecodeError:
            return [text]
    return []


def load_manifest_map() -> dict[str, str]:
    items = json.loads(MANIFEST.read_text(encoding="utf-8"))
    out: dict[str, str] = {}
    for item in items:
        legacy = (item.get("legacy") or "").strip()
        object_path = (item.get("object_path") or "").strip()
        status = (item.get("status") or "").strip()
        if not legacy or not object_path:
            continue
        if status == "missing" or int(item.get("bytes") or 0) <= 0:
            continue
        out.setdefault(legacy, object_path)
        out.setdefault(
            f"{item.get('kind')}:{item.get('legacy_id')}:{legacy}", object_path
        )
    return out


def remap(kind: str, legacy_id: int, urls: list, mmap: dict[str, str]) -> list[str]:
    out = []
    for raw in urls:
        legacy = raw if isinstance(raw, str) else str(raw)
        legacy = legacy.strip()
        if not legacy:
            continue
        owned = mmap.get(f"{kind}:{legacy_id}:{legacy}") or mmap.get(legacy)
        out.append(owned or legacy)
    return out


def amenities(raw):
    rows = parse_json_list(raw)
    out = []
    for i, a in enumerate(rows):
        if not isinstance(a, dict):
            continue
        out.append(
            {
                "name": a.get("name") or "",
                "included": bool(a.get("included", True)),
            }
        )
    return out


def itinerary(raw):
    rows = parse_json_list(raw)
    out = []
    for a in rows:
        if not isinstance(a, dict):
            continue
        out.append(
            {
                "date": a.get("date") or "",
                "location": a.get("location") or "",
                "activity": a.get("activity") or "",
                "description": a.get("description") or "",
            }
        )
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--sync-assets",
        action="store_true",
        help="Also write assets/data/destiny_inventory_catalog.json (post media upload)",
    )
    args = parser.parse_args()

    snap = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
    mmap = load_manifest_map()

    catalog = {
        "version": 1,
        "project": "xchddfpfzrzhlbbmyhyn",
        "image_mode": "owned_media_with_legacy_fallback",
        "tours": [],
        "stays": [],
        "vehicles": [],
        "awards": [],
    }

    for item in snap.get("tours") or []:
        lid = int(item["id"])
        images = remap("tours", lid, parse_json_list(item.get("image_urls_json")), mmap)
        catalog["tours"].append(
            {
                "id": lid,
                "title": item.get("title") or "No Title",
                "description": item.get("description") or "",
                "price": float(item.get("price") or 0),
                "duration": item.get("duration") or "",
                "is_featured": str(item.get("is_featured")) in ("1", "true", "True"),
                "image_urls": images,
                "amenities": amenities(item.get("amenities_json")),
                "itinerary": itinerary(item.get("itinerary_json")),
            }
        )

    for item in snap.get("stays") or []:
        lid = int(item["id"])
        images = remap(
            "stays", lid, parse_json_list(item.get("image_urls_json")), mmap
        )
        rooms = []
        for r in parse_json_list(item.get("room_types_json")):
            if not isinstance(r, dict):
                continue
            rooms.append(
                {
                    "name": r.get("name") or "Room",
                    "price": float(r.get("price") or 0),
                    "capacity": int(r.get("capacity") or 0),
                }
            )
        catalog["stays"].append(
            {
                "id": lid,
                "name": item.get("name") or "No Name",
                "type": item.get("type") or "",
                "description": item.get("description") or "",
                "address": item.get("address") or "",
                "city": item.get("city") or "",
                "country": item.get("country") or "",
                "is_featured": str(item.get("is_featured")) in ("1", "true", "True"),
                "image_urls": images,
                "amenities": amenities(item.get("amenities_json")),
                "room_types": rooms,
            }
        )

    for item in snap.get("vehicles") or []:
        lid = int(item["id"])
        images = remap(
            "vehicles", lid, parse_json_list(item.get("image_urls_json")), mmap
        )
        catalog["vehicles"].append(
            {
                "id": lid,
                "make": item.get("make") or "",
                "model": item.get("model") or "",
                "year": int(item.get("year") or 0),
                "type": item.get("type") or "",
                "price_per_day": float(item.get("price_per_day") or 0),
                "address": item.get("address") or "",
                "city": item.get("city") or "",
                "country": item.get("country") or "",
                "is_featured": str(item.get("is_featured")) in ("1", "true", "True"),
                "image_urls": images,
                "amenities": amenities(item.get("amenities_json")),
            }
        )

    for item in snap.get("awards") or []:
        lid = int(item["id"])
        images = remap(
            "awards",
            lid,
            parse_json_list(item.get("image_url_json") or item.get("image_urls_json")),
            mmap,
        )
        catalog["awards"].append(
            {
                "id": lid,
                "name": item.get("name") or "No Name",
                "description": item.get("description") or "",
                "year": int(item.get("year") or 0),
                "image_urls": images,
            }
        )

    OUT.write_text(json.dumps(catalog, indent=2) + "\n", encoding="utf-8")
    print(
        f"Wrote {OUT} "
        f"tours={len(catalog['tours'])} stays={len(catalog['stays'])} "
        f"vehicles={len(catalog['vehicles'])} awards={len(catalog['awards'])}"
    )

    # Always refresh the owned→legacy fallback map used by Flutter.
    items = json.loads(MANIFEST.read_text(encoding="utf-8"))
    rev: dict[str, str] = {}
    for item in items:
        if not isinstance(item, dict):
            continue
        if item.get("status") == "missing" or int(item.get("bytes") or 0) <= 0:
            continue
        op = (item.get("object_path") or "").strip()
        leg = (item.get("legacy") or "").strip()
        if op.startswith("destiny-media/") and leg:
            rev[op] = leg
    LEGACY_MAP.parent.mkdir(parents=True, exist_ok=True)
    LEGACY_MAP.write_text(json.dumps(rev, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {LEGACY_MAP} entries={len(rev)}")

    if args.sync_assets:
        ASSET.write_text(json.dumps(catalog, separators=(",", ":")) + "\n", encoding="utf-8")
        print(f"Synced {ASSET}")


if __name__ == "__main__":
    main()
