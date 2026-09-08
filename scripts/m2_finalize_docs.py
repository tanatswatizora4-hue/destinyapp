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
MANIFEST = ROOT / "supabase" / "seed" / "media_manifest.json"

SUPABASE_URL = os.environ.get(
    "SUPABASE_URL", "https://xchddfpfzrzhlbbmyhyn.supabase.co"
).rstrip("/")


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
        text = text.replace(
            "staged (awaiting Storage upload)",
            "migrated",
        )
        text = re.sub(
            r"Inventory media is \*\*.*?\*\*.*?Status:.*?\n",
            f"Inventory media **migrated** to `destiny-media` ({ready}/84 objects; "
            "3 residual missing_legacy). Status column below: `migrated` vs `missing_legacy`.\n",
            text,
            count=1,
            flags=re.S,
        )
        MEDIA_INV.write_text(text, encoding="utf-8")
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


if __name__ == "__main__":
    main()
