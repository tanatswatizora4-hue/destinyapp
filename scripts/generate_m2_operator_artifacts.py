#!/usr/bin/env python3
"""Generate operator-facing M2 inventory seed SQL + media manifest.

No credentials. Deterministic. Idempotent upserts on legacy_id.
Source: live bymapara catalog when reachable, else repo snapshot.
Owned media paths come from supabase/seed/media_manifest.json when present;
otherwise legacy upload paths are preserved (never invented).

Outputs:
  scripts/generated/m2_inventory_seed.sql
  scripts/generated/m2_media_manifest.json
  scripts/generated/m2_source_audit.json
"""

from __future__ import annotations

import json
import re
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "scripts" / "generated"
SNAPSHOT = ROOT / "supabase" / "seed" / "legacy_inventory_snapshot.json"
MEDIA_MANIFEST = ROOT / "supabase" / "seed" / "media_manifest.json"
LEGACY_API = "https://bymapara.com/destiny_api.php"


def sql_str(value: Any) -> str:
    if value is None:
        return "NULL"
    text = str(value)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    return "'" + text.replace("'", "''") + "'"


def sql_bool(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    return "true" if str(value) in ("1", "true", "True") else "false"


def sql_num(value: Any, default: float | int | None = 0) -> str:
    if value is None or value == "":
        if default is None:
            return "NULL"
        return str(default)
    try:
        n = float(value)
    except (TypeError, ValueError):
        if default is None:
            return "NULL"
        return str(default)
    if n.is_integer():
        return str(int(n)) if isinstance(default, int) else f"{n:.1f}".rstrip("0").rstrip(".") if "." in f"{n}" else str(int(n))
    return repr(float(n))


def parse_json_list(raw: Any) -> list:
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


def fetch_live() -> dict[str, list[dict]] | None:
    mapping = {
        "tours": "get_tours",
        "stays": "get_accommodations",
        "vehicles": "get_vehicles",
        "awards": "get_awards",
    }
    out: dict[str, list[dict]] = {}
    try:
        for key, action in mapping.items():
            url = f"{LEGACY_API}?action={urllib.parse.quote(action)}"
            with urllib.request.urlopen(url, timeout=60) as resp:
                payload = json.loads(resp.read().decode("utf-8"))
            if not isinstance(payload, dict) or payload.get("status") != "success":
                return None
            data = payload.get("data") or []
            if not isinstance(data, list):
                return None
            out[key] = [r for r in data if isinstance(r, dict)]
        return out
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError):
        return None


def load_snapshot() -> dict[str, list[dict]]:
    raw = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
    out: dict[str, list[dict]] = {}
    for key in ("tours", "stays", "vehicles", "awards"):
        rows = raw.get(key) or []
        out[key] = [r for r in rows if isinstance(r, dict)]
    return out


def load_owned_map() -> dict[str, str]:
    if not MEDIA_MANIFEST.is_file():
        return {}
    items = json.loads(MEDIA_MANIFEST.read_text(encoding="utf-8"))
    out: dict[str, str] = {}
    for item in items:
        if not isinstance(item, dict):
            continue
        legacy = (item.get("legacy") or "").strip()
        object_path = (item.get("object_path") or "").strip()
        status = (item.get("status") or "").strip()
        if not legacy or not object_path:
            continue
        if status == "missing" or int(item.get("bytes") or 0) <= 0:
            continue
        out.setdefault(legacy, object_path)
        kind = item.get("kind")
        legacy_id = item.get("legacy_id")
        if kind is not None and legacy_id is not None:
            out.setdefault(f"{kind}:{legacy_id}:{legacy}", object_path)
    return out


def owned_or_legacy(owned: dict[str, str], kind: str, legacy_id: int, legacy: str) -> str:
    legacy = (legacy or "").strip()
    if not legacy:
        return ""
    return owned.get(f"{kind}:{legacy_id}:{legacy}") or owned.get(legacy) or legacy


def resolve_legacy_url(path: str) -> str:
    path = (path or "").strip()
    if not path:
        return ""
    if path.startswith("http://") or path.startswith("https://"):
        return path
    if path.startswith("/"):
        path = path[1:]
    encoded = "/".join(urllib.parse.quote(seg) for seg in path.split("/"))
    return f"https://bymapara.com/{encoded}"


def text_or_empty(value: Any) -> str:
    """Preserve source text; use empty string when absent (NOT NULL columns)."""
    if value is None:
        return ""
    return str(value)


def require_legacy_id(item: dict) -> int | None:
    raw = item.get("id")
    if raw is None or raw == "":
        return None
    try:
        return int(raw)
    except (TypeError, ValueError):
        return None


def emit_images_sql(
    lines: list[str],
    *,
    child_table: str,
    fk_col: str,
    parent_table: str,
    legacy_id: int,
    image_rows: list[tuple[str, str, int]],
) -> None:
    for storage_path, legacy_url, sort_order in image_rows:
        if not storage_path:
            continue
        lines.append(
            f"INSERT INTO public.{child_table} ({fk_col}, storage_path, legacy_url, sort_order) "
            f"SELECT id, {sql_str(storage_path)}, {sql_str(legacy_url) if legacy_url else 'NULL'}, {sort_order} "
            f"FROM public.{parent_table} WHERE legacy_id={legacy_id};"
        )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    live = fetch_live()
    source_label = "live:bymapara" if live is not None else f"snapshot:{SNAPSHOT.name}"
    catalog = live if live is not None else load_snapshot()
    owned = load_owned_map()

    audit = {
        "source": source_label,
        "counts": {k: len(catalog.get(k) or []) for k in ("tours", "stays", "vehicles", "awards")},
        "skipped_missing_legacy_id": [],
    }

    media_entries: list[dict[str, Any]] = []
    seed_counts = {
        "tours": 0,
        "stays": 0,
        "vehicles": 0,
        "awards": 0,
        "tour_images": 0,
        "tour_amenities": 0,
        "tour_itinerary_items": 0,
        "stay_images": 0,
        "stay_rooms": 0,
        "stay_amenities": 0,
        "vehicle_images": 0,
        "vehicle_features": 0,
        "award_images": 0,
    }

    lines: list[str] = [
        "-- Destiny M2 inventory seed for project xchddfpfzrzhlbbmyhyn ONLY",
        f"-- Generated by scripts/generate_m2_operator_artifacts.py from {source_label}",
        "-- Idempotent: UPSERT parents on legacy_id; replace children for seeded parents.",
        "-- No credentials. Do not apply to Wanzwei.",
        "BEGIN;",
        "",
    ]

    # --- Tours ---
    for item in catalog.get("tours") or []:
        legacy_id = require_legacy_id(item)
        if legacy_id is None:
            audit["skipped_missing_legacy_id"].append({"entity": "tours", "raw": item.get("id")})
            continue
        images = [str(x).strip() for x in parse_json_list(item.get("image_urls_json")) if str(x).strip()]
        image_rows: list[tuple[str, str, int]] = []
        primary: str | None = None
        for idx, legacy in enumerate(images):
            storage = owned_or_legacy(owned, "tours", legacy_id, legacy)
            if idx == 0:
                primary = storage or None
            image_rows.append((storage, legacy, idx))
            media_entries.append(
                {
                    "entity_type": "tours",
                    "legacy_id": legacy_id,
                    "role": "primary" if idx == 0 else f"gallery-{idx:02d}",
                    "source_legacy_path": legacy,
                    "source_legacy_url": resolve_legacy_url(legacy),
                    "target_storage_path": storage,
                    "db_destination": {
                        "parent_table": "tours",
                        "parent_legacy_id": legacy_id,
                        "child_table": "tour_images",
                        "columns": ["storage_path", "legacy_url", "sort_order"],
                        "primary_image_path": idx == 0,
                    },
                    "owned": storage.startswith("destiny-media/"),
                }
            )
        title = text_or_empty(item.get("title"))
        description = text_or_empty(item.get("description"))
        duration = text_or_empty(item.get("duration"))
        price = sql_num(item.get("price"), 0)
        lines.append(
            "INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, "
            "is_featured, is_published, primary_image_path) VALUES ("
            f"{legacy_id}, {sql_str(title)}, {sql_str(description)}, {price}, 'USD', "
            f"{sql_str(duration)}, {sql_bool(item.get('is_featured'))}, true, "
            f"{sql_str(primary) if primary else 'NULL'}) "
            "ON CONFLICT (legacy_id) DO UPDATE SET "
            "title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, "
            "duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, "
            "is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, "
            "updated_at=timezone('utc', now());"
        )
        seed_counts["tours"] += 1

    lines += [
        "DELETE FROM public.tour_images WHERE tour_id IN (SELECT id FROM public.tours WHERE legacy_id IS NOT NULL);",
        "DELETE FROM public.tour_amenities WHERE tour_id IN (SELECT id FROM public.tours WHERE legacy_id IS NOT NULL);",
        "DELETE FROM public.tour_itinerary_items WHERE tour_id IN (SELECT id FROM public.tours WHERE legacy_id IS NOT NULL);",
    ]

    for item in catalog.get("tours") or []:
        legacy_id = require_legacy_id(item)
        if legacy_id is None:
            continue
        images = [str(x).strip() for x in parse_json_list(item.get("image_urls_json")) if str(x).strip()]
        image_rows = [
            (owned_or_legacy(owned, "tours", legacy_id, legacy), legacy, idx)
            for idx, legacy in enumerate(images)
        ]
        emit_images_sql(
            lines,
            child_table="tour_images",
            fk_col="tour_id",
            parent_table="tours",
            legacy_id=legacy_id,
            image_rows=image_rows,
        )
        seed_counts["tour_images"] += sum(1 for s, _, __ in image_rows if s)
        for i, a in enumerate(parse_json_list(item.get("amenities_json"))):
            if not isinstance(a, dict):
                continue
            name = text_or_empty(a.get("name"))
            if not name:
                continue
            lines.append(
                "INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) "
                f"SELECT id, {sql_str(name)}, {sql_bool(a.get('included', True))}, {i} "
                f"FROM public.tours WHERE legacy_id={legacy_id};"
            )
            seed_counts["tour_amenities"] += 1
        for i, a in enumerate(parse_json_list(item.get("itinerary_json"))):
            if not isinstance(a, dict):
                continue
            lines.append(
                "INSERT INTO public.tour_itinerary_items "
                "(tour_id, date_label, location, activity, description, sort_order) "
                f"SELECT id, {sql_str(text_or_empty(a.get('date')))}, "
                f"{sql_str(text_or_empty(a.get('location')))}, "
                f"{sql_str(text_or_empty(a.get('activity')))}, "
                f"{sql_str(text_or_empty(a.get('description')))}, {i} "
                f"FROM public.tours WHERE legacy_id={legacy_id};"
            )
            seed_counts["tour_itinerary_items"] += 1

    # --- Stays ---
    for item in catalog.get("stays") or []:
        legacy_id = require_legacy_id(item)
        if legacy_id is None:
            audit["skipped_missing_legacy_id"].append({"entity": "stays", "raw": item.get("id")})
            continue
        images = [str(x).strip() for x in parse_json_list(item.get("image_urls_json")) if str(x).strip()]
        primary = None
        for idx, legacy in enumerate(images):
            storage = owned_or_legacy(owned, "stays", legacy_id, legacy)
            if idx == 0:
                primary = storage or None
            media_entries.append(
                {
                    "entity_type": "stays",
                    "legacy_id": legacy_id,
                    "role": "primary" if idx == 0 else f"gallery-{idx:02d}",
                    "source_legacy_path": legacy,
                    "source_legacy_url": resolve_legacy_url(legacy),
                    "target_storage_path": storage,
                    "db_destination": {
                        "parent_table": "stays",
                        "parent_legacy_id": legacy_id,
                        "child_table": "stay_images",
                        "columns": ["storage_path", "legacy_url", "sort_order"],
                        "primary_image_path": idx == 0,
                    },
                    "owned": storage.startswith("destiny-media/"),
                }
            )
        lines.append(
            "INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, "
            "is_featured, is_published, primary_image_path, currency) VALUES ("
            f"{legacy_id}, {sql_str(text_or_empty(item.get('name')))}, "
            f"{sql_str(text_or_empty(item.get('type')))}, "
            f"{sql_str(text_or_empty(item.get('description')))}, "
            f"{sql_str(text_or_empty(item.get('address')))}, "
            f"{sql_str(text_or_empty(item.get('city')))}, "
            f"{sql_str(text_or_empty(item.get('country')))}, "
            f"{sql_bool(item.get('is_featured'))}, true, "
            f"{sql_str(primary) if primary else 'NULL'}, 'USD') "
            "ON CONFLICT (legacy_id) DO UPDATE SET "
            "name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, "
            "address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, "
            "is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, "
            "primary_image_path=EXCLUDED.primary_image_path, "
            "updated_at=timezone('utc', now());"
        )
        seed_counts["stays"] += 1

    lines += [
        "DELETE FROM public.stay_images WHERE stay_id IN (SELECT id FROM public.stays WHERE legacy_id IS NOT NULL);",
        "DELETE FROM public.stay_rooms WHERE stay_id IN (SELECT id FROM public.stays WHERE legacy_id IS NOT NULL);",
        "DELETE FROM public.stay_amenities WHERE stay_id IN (SELECT id FROM public.stays WHERE legacy_id IS NOT NULL);",
    ]

    for item in catalog.get("stays") or []:
        legacy_id = require_legacy_id(item)
        if legacy_id is None:
            continue
        images = [str(x).strip() for x in parse_json_list(item.get("image_urls_json")) if str(x).strip()]
        image_rows = [
            (owned_or_legacy(owned, "stays", legacy_id, legacy), legacy, idx)
            for idx, legacy in enumerate(images)
        ]
        emit_images_sql(
            lines,
            child_table="stay_images",
            fk_col="stay_id",
            parent_table="stays",
            legacy_id=legacy_id,
            image_rows=image_rows,
        )
        seed_counts["stay_images"] += sum(1 for s, _, __ in image_rows if s)
        # Legacy PHP field is room_types_json (not rooms_json).
        for i, room in enumerate(parse_json_list(item.get("room_types_json"))):
            if not isinstance(room, dict):
                continue
            name = text_or_empty(room.get("name"))
            if not name:
                continue
            capacity_raw = room.get("capacity")
            try:
                capacity = int(capacity_raw) if capacity_raw not in (None, "") else 0
            except (TypeError, ValueError):
                capacity = 0
            lines.append(
                "INSERT INTO public.stay_rooms (stay_id, name, price, capacity, sort_order) "
                f"SELECT id, {sql_str(name)}, {sql_num(room.get('price'), 0)}, {capacity}, {i} "
                f"FROM public.stays WHERE legacy_id={legacy_id};"
            )
            seed_counts["stay_rooms"] += 1
        for i, a in enumerate(parse_json_list(item.get("amenities_json"))):
            if not isinstance(a, dict):
                continue
            name = text_or_empty(a.get("name"))
            if not name:
                continue
            lines.append(
                "INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) "
                f"SELECT id, {sql_str(name)}, {sql_bool(a.get('included', True))}, {i} "
                f"FROM public.stays WHERE legacy_id={legacy_id};"
            )
            seed_counts["stay_amenities"] += 1

    # --- Vehicles ---
    for item in catalog.get("vehicles") or []:
        legacy_id = require_legacy_id(item)
        if legacy_id is None:
            audit["skipped_missing_legacy_id"].append({"entity": "vehicles", "raw": item.get("id")})
            continue
        images = [str(x).strip() for x in parse_json_list(item.get("image_urls_json")) if str(x).strip()]
        primary = None
        for idx, legacy in enumerate(images):
            storage = owned_or_legacy(owned, "vehicles", legacy_id, legacy)
            if idx == 0:
                primary = storage or None
            media_entries.append(
                {
                    "entity_type": "vehicles",
                    "legacy_id": legacy_id,
                    "role": "primary" if idx == 0 else f"gallery-{idx:02d}",
                    "source_legacy_path": legacy,
                    "source_legacy_url": resolve_legacy_url(legacy),
                    "target_storage_path": storage,
                    "db_destination": {
                        "parent_table": "vehicles",
                        "parent_legacy_id": legacy_id,
                        "child_table": "vehicle_images",
                        "columns": ["storage_path", "legacy_url", "sort_order"],
                        "primary_image_path": idx == 0,
                    },
                    "owned": storage.startswith("destiny-media/"),
                }
            )
        year_raw = item.get("year")
        try:
            year_sql = str(int(year_raw)) if year_raw not in (None, "") else "NULL"
        except (TypeError, ValueError):
            year_sql = "NULL"
        lines.append(
            "INSERT INTO public.vehicles (legacy_id, make, model, year, type, price_per_day, currency, "
            "address, city, country, is_featured, is_published, primary_image_path) VALUES ("
            f"{legacy_id}, {sql_str(text_or_empty(item.get('make')))}, "
            f"{sql_str(text_or_empty(item.get('model')))}, {year_sql}, "
            f"{sql_str(text_or_empty(item.get('type')))}, "
            f"{sql_num(item.get('price_per_day'), 0)}, 'USD', "
            f"{sql_str(text_or_empty(item.get('address')))}, "
            f"{sql_str(text_or_empty(item.get('city')))}, "
            f"{sql_str(text_or_empty(item.get('country')))}, "
            f"{sql_bool(item.get('is_featured'))}, true, "
            f"{sql_str(primary) if primary else 'NULL'}) "
            "ON CONFLICT (legacy_id) DO UPDATE SET "
            "make=EXCLUDED.make, model=EXCLUDED.model, year=EXCLUDED.year, type=EXCLUDED.type, "
            "price_per_day=EXCLUDED.price_per_day, address=EXCLUDED.address, city=EXCLUDED.city, "
            "country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, "
            "is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, "
            "updated_at=timezone('utc', now());"
        )
        seed_counts["vehicles"] += 1

    lines += [
        "DELETE FROM public.vehicle_images WHERE vehicle_id IN (SELECT id FROM public.vehicles WHERE legacy_id IS NOT NULL);",
        "DELETE FROM public.vehicle_features WHERE vehicle_id IN (SELECT id FROM public.vehicles WHERE legacy_id IS NOT NULL);",
    ]

    for item in catalog.get("vehicles") or []:
        legacy_id = require_legacy_id(item)
        if legacy_id is None:
            continue
        images = [str(x).strip() for x in parse_json_list(item.get("image_urls_json")) if str(x).strip()]
        image_rows = [
            (owned_or_legacy(owned, "vehicles", legacy_id, legacy), legacy, idx)
            for idx, legacy in enumerate(images)
        ]
        emit_images_sql(
            lines,
            child_table="vehicle_images",
            fk_col="vehicle_id",
            parent_table="vehicles",
            legacy_id=legacy_id,
            image_rows=image_rows,
        )
        seed_counts["vehicle_images"] += sum(1 for s, _, __ in image_rows if s)
        # Legacy PHP stores vehicle features in amenities_json.
        for i, a in enumerate(parse_json_list(item.get("amenities_json"))):
            if not isinstance(a, dict):
                continue
            name = text_or_empty(a.get("name"))
            if not name:
                continue
            lines.append(
                "INSERT INTO public.vehicle_features (vehicle_id, name, included, sort_order) "
                f"SELECT id, {sql_str(name)}, {sql_bool(a.get('included', True))}, {i} "
                f"FROM public.vehicles WHERE legacy_id={legacy_id};"
            )
            seed_counts["vehicle_features"] += 1

    # --- Awards ---
    for item in catalog.get("awards") or []:
        legacy_id = require_legacy_id(item)
        if legacy_id is None:
            audit["skipped_missing_legacy_id"].append({"entity": "awards", "raw": item.get("id")})
            continue
        # Legacy PHP field is image_url_json (string or JSON list).
        images = [
            str(x).strip()
            for x in parse_json_list(item.get("image_url_json"))
            if str(x).strip()
        ]
        primary = None
        for idx, legacy in enumerate(images):
            storage = owned_or_legacy(owned, "awards", legacy_id, legacy)
            if idx == 0:
                primary = storage or None
            media_entries.append(
                {
                    "entity_type": "awards",
                    "legacy_id": legacy_id,
                    "role": "primary" if idx == 0 else f"gallery-{idx:02d}",
                    "source_legacy_path": legacy,
                    "source_legacy_url": resolve_legacy_url(legacy),
                    "target_storage_path": storage,
                    "db_destination": {
                        "parent_table": "awards",
                        "parent_legacy_id": legacy_id,
                        "child_table": "award_images",
                        "columns": ["storage_path", "legacy_url", "sort_order"],
                        "primary_image_path": idx == 0,
                    },
                    "owned": storage.startswith("destiny-media/"),
                }
            )
        year_raw = item.get("year")
        try:
            year_sql = str(int(year_raw)) if year_raw not in (None, "") else "NULL"
        except (TypeError, ValueError):
            year_sql = "NULL"
        lines.append(
            "INSERT INTO public.awards (legacy_id, name, description, year, is_published, primary_image_path) VALUES ("
            f"{legacy_id}, {sql_str(text_or_empty(item.get('name')))}, "
            f"{sql_str(text_or_empty(item.get('description')))}, {year_sql}, true, "
            f"{sql_str(primary) if primary else 'NULL'}) "
            "ON CONFLICT (legacy_id) DO UPDATE SET "
            "name=EXCLUDED.name, description=EXCLUDED.description, year=EXCLUDED.year, "
            "is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, "
            "updated_at=timezone('utc', now());"
        )
        seed_counts["awards"] += 1

    lines.append(
        "DELETE FROM public.award_images WHERE award_id IN (SELECT id FROM public.awards WHERE legacy_id IS NOT NULL);"
    )

    for item in catalog.get("awards") or []:
        legacy_id = require_legacy_id(item)
        if legacy_id is None:
            continue
        images = [
            str(x).strip()
            for x in parse_json_list(item.get("image_url_json"))
            if str(x).strip()
        ]
        image_rows = [
            (owned_or_legacy(owned, "awards", legacy_id, legacy), legacy, idx)
            for idx, legacy in enumerate(images)
        ]
        emit_images_sql(
            lines,
            child_table="award_images",
            fk_col="award_id",
            parent_table="awards",
            legacy_id=legacy_id,
            image_rows=image_rows,
        )
        seed_counts["award_images"] += sum(1 for s, _, __ in image_rows if s)

    lines += ["", "COMMIT;", ""]

    seed_path = OUT / "m2_inventory_seed.sql"
    seed_path.write_text("\n".join(lines), encoding="utf-8", newline="\n")

    owned_count = sum(1 for e in media_entries if e.get("owned"))
    missing_owned = sum(1 for e in media_entries if not e.get("owned"))
    media_doc = {
        "version": 1,
        "project": "xchddfpfzrzhlbbmyhyn",
        "bucket": "destiny-media",
        "source": source_label,
        "note": (
            "Operator uploads target_storage_path objects into destiny-media "
            "(strip destiny-media/ prefix for Storage keys). "
            "Entries with owned=false still use legacy upload paths in DB until remapped."
        ),
        "totals": {
            "entries": len(media_entries),
            "owned_destiny_media": owned_count,
            "legacy_path_retained": missing_owned,
        },
        "entries": media_entries,
    }
    media_path = OUT / "m2_media_manifest.json"
    media_path.write_text(json.dumps(media_doc, indent=2) + "\n", encoding="utf-8")

    audit["seed_record_counts"] = seed_counts
    audit["media_totals"] = media_doc["totals"]
    (OUT / "m2_source_audit.json").write_text(
        json.dumps(audit, indent=2) + "\n", encoding="utf-8"
    )

    readme = OUT / "README.md"
    readme.write_text(
        "\n".join(
            [
                "# M2 operator artifacts (no credentials)",
                "",
                "Target project: `xchddfpfzrzhlbbmyhyn` only.",
                "",
                "## Files",
                "",
                "- `m2_inventory_seed.sql` — idempotent inventory upsert (parents + children)",
                "- `m2_media_manifest.json` — legacy → destiny-media transfer map",
                "- `m2_source_audit.json` — source counts / seed counts",
                "",
                "## External action",
                "",
                "1. Run `m2_inventory_seed.sql` in the Destiny SQL editor (privileged).",
                "2. Upload media per `m2_media_manifest.json` into bucket `destiny-media`.",
                "3. Confirm counts tours/stays/vehicles/awards = 25/36/3/6 and catalog.json HTTP 200.",
                "",
                "Regenerate: `python3 scripts/generate_m2_operator_artifacts.py`",
                "",
            ]
        ),
        encoding="utf-8",
    )

    print(f"SOURCE={source_label}")
    print(f"COUNTS={audit['counts']}")
    print(f"SEED={seed_path}")
    print(f"MEDIA={media_path}")
    print(f"SEED_RECORD_COUNTS={json.dumps(seed_counts)}")
    print(f"MEDIA_TOTALS={json.dumps(media_doc['totals'])}")


if __name__ == "__main__":
    main()
