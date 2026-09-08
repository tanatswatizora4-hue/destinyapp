#!/usr/bin/env python3
"""Verify Destiny M2 inventory on remote Supabase (destiny-os only).

Uses DESTINY_SUPABASE_ANON_KEY by default (public RLS path).
Pass --service-role to use SUPABASE_SERVICE_ROLE_KEY instead.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

SUPABASE_URL = os.environ.get(
    "SUPABASE_URL", "https://xchddfpfzrzhlbbmyhyn.supabase.co"
).rstrip("/")
EXPECTED = {"tours": 25, "stays": 36, "vehicles": 3, "awards": 6}
CATALOG_URL = (
    f"{SUPABASE_URL}/storage/v1/object/public/destiny-media/inventory/catalog.json"
)
SAMPLE_OBJECTS = [
    "tours/39/primary.jpg",
    "stays/1/primary.jpg",
    "vehicles/1/primary.webp",
    "awards/5/primary.jpg",
]
SENSITIVE = ["bookings", "customer_profiles", "enquiries"]


def die(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def fetch(url: str, headers: dict) -> tuple[int, str, dict]:
    req = urllib.request.Request(url, method="GET")
    for k, v in headers.items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.status, resp.read().decode("utf-8"), dict(resp.headers)
    except urllib.error.HTTPError as exc:
        return (
            exc.code,
            exc.read().decode("utf-8", errors="replace"),
            dict(exc.headers),
        )


def count_table(table: str, key: str) -> int:
    url = f"{SUPABASE_URL}/rest/v1/{table}?select=id&is_published=eq.true"
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Prefer": "count=exact",
        "Range": "0-0",
    }
    code, body, hdrs = fetch(url, headers)
    if code >= 400:
        die(f"{table} HTTP {code}: {body}")
    content_range = hdrs.get("content-range") or hdrs.get("Content-Range") or ""
    if "/" in content_range:
        total = content_range.split("/")[-1]
        if total.isdigit():
            return int(total)
    rows = json.loads(body) if body else []
    return len(rows) if isinstance(rows, list) else -1


def sample_owned_paths(table: str, key: str) -> tuple[int, int]:
    """Return (owned_count, total_sampled) for primary_image_path."""
    url = (
        f"{SUPABASE_URL}/rest/v1/{table}"
        f"?select=primary_image_path&is_published=eq.true&limit=50"
    )
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
    }
    code, body, _ = fetch(url, headers)
    if code >= 400:
        die(f"{table} path sample HTTP {code}: {body}")
    rows = json.loads(body) if body else []
    owned = 0
    total = 0
    for row in rows:
        path = (row.get("primary_image_path") or "").strip()
        if not path:
            continue
        total += 1
        if path.startswith("destiny-media/"):
            owned += 1
    return owned, total


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--service-role",
        action="store_true",
        help="Use SUPABASE_SERVICE_ROLE_KEY instead of anon",
    )
    args = parser.parse_args()

    if "xchddfpfzrzhlbbmyhyn" not in SUPABASE_URL:
        die(f"refusing non-destiny-os URL: {SUPABASE_URL}")

    if args.service_role:
        key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        if not key:
            die("SUPABASE_SERVICE_ROLE_KEY required with --service-role")
        mode = "service_role"
    else:
        key = os.environ.get("DESTINY_SUPABASE_ANON_KEY", "").strip()
        if not key:
            die("DESTINY_SUPABASE_ANON_KEY required (or pass --service-role)")
        mode = "anon"

    print(f"Verify mode={mode} url={SUPABASE_URL}")
    ok = True
    for table, expected in EXPECTED.items():
        n = count_table(table, key)
        status = "OK" if n == expected else "MISMATCH"
        if n != expected:
            ok = False
        print(f"  {table}: {n} (expected {expected}) [{status}]")
        owned, total = sample_owned_paths(table, key)
        print(f"    primary_image_path owned={owned}/{total}")
        if total > 0 and owned == 0:
            ok = False
            print("    ERROR: no destiny-media primary paths")

    code, body, _ = fetch(CATALOG_URL, {})
    if code == 200:
        try:
            catalog = json.loads(body)
            print(
                "  catalog.json: OK "
                f"tours={len(catalog.get('tours') or [])} "
                f"stays={len(catalog.get('stays') or [])} "
                f"vehicles={len(catalog.get('vehicles') or [])} "
                f"awards={len(catalog.get('awards') or [])}"
            )
        except json.JSONDecodeError:
            ok = False
            print("  catalog.json: invalid JSON")
    else:
        ok = False
        print(f"  catalog.json: HTTP {code}")

    for obj in SAMPLE_OBJECTS:
        url = f"{SUPABASE_URL}/storage/v1/object/public/destiny-media/{obj}"
        code, _, _ = fetch(url, {})
        status = "OK" if code == 200 else f"HTTP {code}"
        if code != 200:
            ok = False
        print(f"  media {obj}: {status}")

    if mode == "anon":
        for table in SENSITIVE:
            url = f"{SUPABASE_URL}/rest/v1/{table}?select=id&limit=1"
            code, body, _ = fetch(
                url,
                {
                    "apikey": key,
                    "Authorization": f"Bearer {key}",
                },
            )
            # Expect empty/401/403 — never readable rows for anon.
            if code == 200:
                rows = json.loads(body) if body else []
                if rows:
                    ok = False
                    print(f"  sensitive {table}: LEAK rows={len(rows)}")
                else:
                    print(f"  sensitive {table}: OK empty ({code})")
            elif code in (401, 403, 404):
                print(f"  sensitive {table}: OK denied ({code})")
            else:
                print(f"  sensitive {table}: HTTP {code}")

    if not ok:
        die("verification failed")
    print("M2 remote verification passed")


if __name__ == "__main__":
    main()
