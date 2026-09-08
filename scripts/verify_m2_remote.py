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


def die(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def fetch(url: str, headers: dict) -> tuple[int, str]:
    req = urllib.request.Request(url, method="GET")
    for k, v in headers.items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.status, resp.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", errors="replace")


def count_table(table: str, key: str) -> int:
    url = (
        f"{SUPABASE_URL}/rest/v1/{table}"
        f"?select=id&is_published=eq.true"
    )
    # Prefer exact count header
    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Prefer": "count=exact",
        "Range": "0-0",
    }
    req = urllib.request.Request(url, method="GET")
    for k, v in headers.items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            content_range = resp.headers.get("content-range") or ""
            # content-range: 0-0/25
            if "/" in content_range:
                total = content_range.split("/")[-1]
                if total.isdigit():
                    return int(total)
            body = resp.read().decode("utf-8")
            rows = json.loads(body) if body else []
            return len(rows) if isinstance(rows, list) else -1
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        die(f"{table} HTTP {exc.code}: {detail}")


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

    code, body = fetch(CATALOG_URL, {})
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

    if not ok:
        die("verification failed")
    print("M2 remote verification passed")


if __name__ == "__main__":
    main()
