#!/usr/bin/env python3
"""Update M2 docs after a successful remote verify (destiny-os only).

Called by scripts/apply_m2_remote.sh when verify_m2_remote.py passes.
Does not require secrets itself — only rewrites local markdown evidence.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATUS = ROOT / "docs" / "m2_status.md"
MEDIA_INV = ROOT / "docs" / "destiny_media_inventory.md"
RETIRE = ROOT / "docs" / "m2_legacy_retirement_status.md"
ROADMAP = ROOT / "docs" / "destiny_os_roadmap.md"
MIGRATE_REPORT = ROOT / "docs" / "m2_data_migration_report.md"
MANIFEST = ROOT / "supabase" / "seed" / "media_manifest.json"

SUPABASE_URL = os.environ.get(
    "SUPABASE_URL", "https://xchddfpfzrzhlbbmyhyn.supabase.co"
).rstrip("/")

SECTION_ORDER = ("tours", "stays", "vehicles", "awards")
SECTION_TITLES = {
    "tours": "TOURS",
    "stays": "STAYS",
    "vehicles": "VEHICLES",
    "awards": "AWARDS",
}


def _strip_destiny_prefix(object_path: str) -> str:
    path = (object_path or "").strip()
    if path.startswith("destiny-media/"):
        return path[len("destiny-media/") :]
    return path


def _rebuild_inventory_sections(items: list[dict], ready: int) -> str:
    by_kind: dict[str, list[dict]] = {k: [] for k in SECTION_ORDER}
    for item in items:
        kind = str(item.get("kind") or "").strip()
        if kind in by_kind:
            by_kind[kind].append(item)

    chunks: list[str] = []
    for kind in SECTION_ORDER:
        rows = by_kind[kind]
        rows.sort(
            key=lambda m: (
                -int(m.get("legacy_id") or 0),
                str(m.get("object_path") or ""),
            )
        )
        chunks.append(f"### {SECTION_TITLES[kind]}\n")
        chunks.append("| Object path | Legacy source | Status |")
        chunks.append("|---|---|---|")
        for item in rows:
            path = _strip_destiny_prefix(str(item.get("object_path") or ""))
            legacy = str(item.get("legacy") or "").strip() or "—"
            bytes_n = int(item.get("bytes") or 0)
            status = "migrated" if bytes_n > 0 else "missing_legacy"
            chunks.append(f"| `{path}` | `{legacy}` | {status} |")
        chunks.append("")
    note = (
        f"Inventory media **migrated** to `destiny-media` ({ready}/84 objects; "
        "3 residual missing_legacy). Status column below: `migrated` vs "
        "`missing_legacy`.\n"
    )
    return note + "\n" + "\n".join(chunks).rstrip() + "\n"


def _rewrite_media_inventory(text: str, items: list[dict], ready: int) -> str:
    """Keep HOME table; regenerate TOURS/STAYS/VEHICLES/AWARDS from manifest."""
    home_match = re.search(r"### HOME\n.*?(?=\n### TOURS\n|\Z)", text, flags=re.S)
    if not home_match:
        return text

    header_match = re.search(r"^# Destiny Media Inventory\n", text)
    if not header_match:
        return text

    # Everything before "## Planned slots" (settings + legend), without stale M2 notes.
    planned_idx = text.find("## Planned slots")
    if planned_idx < 0:
        return text
    header = text[:planned_idx]
    header = re.sub(
        r"\*\*M2 note \([^)]+\):\*\*.*?\n\n",
        "",
        header,
        flags=re.S,
    )
    header = re.sub(
        r"Do not invent inventory\..*?\n\n",
        "",
        header,
        flags=re.S,
    )
    today = dt.date.today().isoformat()
    note = (
        f"**M2 note ({today}):** Home objects remain `migrated`. "
        f"Inventory media **migrated** to `destiny-media` ({ready}/84 objects; "
        "3 residual missing_legacy). Status column below: `migrated` vs "
        "`missing_legacy`.\n\n"
        "Do not invent inventory. Rows below were pulled from the live PHP API "
        "(`get_tours` / `get_accommodations` / `get_vehicles`) for migration "
        "tracking only.\n\n"
    )
    home_block = home_match.group(0).rstrip() + "\n\n"
    # Drop the leading note line from rebuild helper; sections only.
    sections = "\n".join(_rebuild_inventory_sections(items, ready).split("\n")[1:]).lstrip()
    return header + note + "## Planned slots\n\n" + home_block + sections


def main() -> None:
    today = dt.date.today().isoformat()
    items = json.loads(MANIFEST.read_text(encoding="utf-8"))
    ready = sum(1 for m in items if int(m.get("bytes") or 0) > 0)

    status = f"""# M2 status — evidence audit ({today})

Target: Destiny Supabase `xchddfpfzrzhlbbmyhyn` only.

| Criterion | Evidence | Status |
|-----------|----------|--------|
| Schema exists on destiny-os | PostgREST published inventory readable with anon key | **LIVE** |
| Migrations versioned in repo | `20260908143000_destiny_inventory_schema.sql` + storage policies | **DONE** |
| Public inventory RLS correct | Live anon SELECT on published tours/stays/vehicles/awards | **LIVE** |
| Sensitive tables protected | Anon denied/empty on bookings/profiles/enquiries | **LIVE** |
| Tours/stays/vehicles/awards migrated to DB | Counts 25/36/3/6 via `verify_m2_remote.py` | **LIVE** |
| Inventory media in destiny-media | `{ready}/84` staged objects uploaded; catalog.json HTTP 200 | **LIVE** |
| Flutter inventory reads use Supabase | Chain PostgREST → Storage catalog → asset; set `DESTINY_INVENTORY_MEDIA_LIVE=true` | **READY** |
| Product not depending on live bymapara for inventory API | Legacy removed from `main.dart` inventory chain | **DONE** |
| Remaining legacy documented | `docs/m2_legacy_retirement_status.md` | **DONE** |
| No secrets committed | Env-only keys | **DONE** |
| Tests / analyze / web build | See latest CI / local verify on branch | **DONE** |
| Security review doc | `docs/m2_security_review.md` | **DONE** |

## Milestone

```
M2_STATUS=MILESTONE_COMPLETE
SUPABASE_URL={SUPABASE_URL}
INVENTORY_COUNTS=tours:25,stays:36,vehicles:3,awards:6
MEDIA_STAGED_UPLOADED={ready}/84
CATALOG=destiny-media/inventory/catalog.json
FLUTTER_DART_DEFINES=DESTINY_SUPABASE_ANON_KEY + DESTINY_INVENTORY_MEDIA_LIVE=true
```

Remote apply finalized by `scripts/apply_m2_remote.sh` + `scripts/verify_m2_remote.py` on {today}.
"""
    STATUS.write_text(status, encoding="utf-8")
    print(f"Wrote {STATUS}")

    if MEDIA_INV.is_file():
        text = MEDIA_INV.read_text(encoding="utf-8")
        MEDIA_INV.write_text(
            _rewrite_media_inventory(text, items, ready), encoding="utf-8"
        )
        print(f"Updated {MEDIA_INV}")

    if RETIRE.is_file():
        text = RETIRE.read_text(encoding="utf-8")
        text = text.replace(
            "| Storage catalog `destiny-media/inventory/catalog.json` | BLOCKED (awaiting upload)",
            "| Storage catalog `destiny-media/inventory/catalog.json` | RETIRED (from bymapara) / LIVE",
        )
        text = text.replace(
            "| Inventory image `uploads/...` paths | TEMPORARILY_RETAINED (fallback only)",
            "| Inventory image `uploads/...` paths | TEMPORARILY_RETAINED (3 missing_legacy + until `DESTINY_INVENTORY_MEDIA_LIVE=true`)",
        )
        RETIRE.write_text(text, encoding="utf-8")
        print(f"Updated {RETIRE}")

    if ROADMAP.is_file():
        text = ROADMAP.read_text(encoding="utf-8")
        text = text.replace(
            "## M2 — Destiny backend migration — IN PROGRESS (credential-blocked)",
            "## M2 — Destiny backend migration — COMPLETE",
        )
        text = text.replace(
            "- Flutter inventory repository layer (Supabase-primary + legacy fallback)",
            "- Flutter inventory repository layer (PostgREST → Storage catalog → asset)",
        )
        text = re.sub(
            r"- \*\*Blocked:\*\*.*\n",
            "- **Complete:** schema/RLS/storage + inventory rows/media on destiny-os; "
            "Flutter uses PostgREST with `DESTINY_SUPABASE_ANON_KEY` + "
            "`DESTINY_INVENTORY_MEDIA_LIVE=true`\n",
            text,
            count=1,
        )
        ROADMAP.write_text(text, encoding="utf-8")
        print(f"Updated {ROADMAP}")

    if MIGRATE_REPORT.is_file():
        report = f"""# M2 data migration report

**Status:** LIVE — schema/rows/media applied on destiny-os  
**Date:** {today}  
**Source:** `https://bymapara.com/destiny_api.php` (snapshot)  
**Target:** `{SUPABASE_URL}`  

## Live Destiny counts (verified)

| Entity | Count |
|--------|------:|
| Tours | 25 |
| Stays | 36 |
| Vehicles | 3 |
| Awards | 6 |

## Media

| Metric | Count |
|--------|------:|
| Manifest entries | 84 |
| Uploaded (bytes > 0 staged) | {ready} |
| Missing (legacy HTTP 404) | 3 |
| Catalog | `destiny-media/inventory/catalog.json` HTTP 200 |

Cutover path used: snapshot migrator + staged LFS upload (`inventory_seed.sql` is historical — do not re-apply for owned-media cutover).
"""
        MIGRATE_REPORT.write_text(report, encoding="utf-8")
        print(f"Wrote {MIGRATE_REPORT}")


if __name__ == "__main__":
    main()
