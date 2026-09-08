#!/usr/bin/env python3
"""Offline M2 preflight — validates repo artifacts without Supabase secrets."""

from __future__ import annotations

import json
import sys
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {"tours": 25, "stays": 36, "vehicles": 3, "awards": 6}
errors: list[str] = []


def check(cond: bool, msg: str) -> None:
    if not cond:
        errors.append(msg)
        print(f"FAIL  {msg}")
    else:
        print(f"OK    {msg}")


def main() -> None:
    snap = ROOT / "supabase/seed/legacy_inventory_snapshot.json"
    catalog = ROOT / "supabase/seed/destiny_inventory_catalog.json"
    asset = ROOT / "assets/data/destiny_inventory_catalog.json"
    manifest = ROOT / "supabase/seed/media_manifest.json"
    legacy_map = ROOT / "assets/data/destiny_media_legacy_map.json"
    tarball = ROOT / "supabase/seed/destiny-inventory-media-staged.tar"
    schema = ROOT / "supabase/migrations/20260908143000_destiny_inventory_schema.sql"
    storage = ROOT / "supabase/migrations/20260908170000_destiny_media_storage_policies.sql"

    for p in (snap, catalog, asset, manifest, legacy_map, schema, storage):
        check(p.is_file(), f"exists {p.relative_to(ROOT)}")

    data = json.loads(snap.read_text(encoding="utf-8"))
    for key, n in EXPECTED.items():
        check(len(data.get(key) or []) == n, f"snapshot {key}=={n}")

    cat = json.loads(catalog.read_text(encoding="utf-8"))
    for key, n in EXPECTED.items():
        check(len(cat.get(key) or []) == n, f"seed catalog {key}=={n}")

    owned = uploads = 0
    for key in EXPECTED:
        for row in cat[key]:
            for u in row.get("image_urls") or []:
                if str(u).startswith("destiny-media/"):
                    owned += 1
                elif str(u).startswith("uploads/"):
                    uploads += 1
    check(owned >= 80, f"seed catalog owned paths >=80 (got {owned})")
    check(uploads <= 5, f"seed catalog residual uploads <=5 (got {uploads})")

    items = json.loads(manifest.read_text(encoding="utf-8"))
    check(len(items) == 84, f"manifest entries==84 (got {len(items)})")
    ready = sum(1 for m in items if int(m.get("bytes") or 0) > 0)
    check(ready == 81, f"manifest ready bytes>0 ==81 (got {ready})")

    amap = json.loads(legacy_map.read_text(encoding="utf-8"))
    check(len(amap) == 81, f"legacy map entries==81 (got {len(amap)})")

    check(tarball.is_file(), "seed media tarball present (Git LFS)")
    if tarball.is_file():
        head = tarball.read_bytes()[:80]
        if head.startswith(b"version https://git-lfs.github.com/spec/v1"):
            errors.append("tarball is an LFS pointer — run: git lfs pull")
            print("FAIL  tarball is an LFS pointer — run: git lfs pull")
        else:
            with tarfile.open(tarball, "r") as tar:
                files = [m for m in tar.getmembers() if m.isfile()]
            check(len(files) >= 81, f"tarball files>=81 (got {len(files)})")

    sql = schema.read_text(encoding="utf-8")
    check("enable row level security" in sql.lower(), "schema enables RLS")
    check("customer_profiles" in sql and "bookings" in sql, "schema has sensitive stubs")
    stor = storage.read_text(encoding="utf-8")
    check("destiny_media_public_read" in stor, "storage public-read policy present")
    check("to anon, authenticated" in stor.lower() or "to anon, authenticated" in stor, "storage policy grants anon read")

    if errors:
        print(f"\nPreflight FAILED ({len(errors)} issues)")
        sys.exit(1)
    print("\nPreflight PASSED — ready for credentialed apply_m2_remote.sh")


if __name__ == "__main__":
    main()
