#!/usr/bin/env python3
"""Apply SQL files to destiny-os via Supabase Management API.

Required:
  SUPABASE_ACCESS_TOKEN  (Dashboard → Account → Access Tokens)
  SUPABASE_PROJECT_REF=xchddfpfzrzhlbbmyhyn

Usage:
  python3 scripts/apply_sql_management_api.py supabase/migrations/*.sql
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

PROJECT_REF = os.environ.get("SUPABASE_PROJECT_REF", "xchddfpfzrzhlbbmyhyn").strip()
TOKEN = os.environ.get("SUPABASE_ACCESS_TOKEN", "").strip()
ALLOWED = {"xchddfpfzrzhlbbmyhyn"}


def die(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def apply_sql(sql: str, label: str) -> None:
    url = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query"
    body = json.dumps({"query": sql}).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Authorization", f"Bearer {TOKEN}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            raw = resp.read().decode("utf-8")
            print(f"OK {label} ({resp.status}) {raw[:200]}")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        die(f"{label} failed HTTP {exc.code}: {detail}")


def main() -> None:
    if not TOKEN:
        die("SUPABASE_ACCESS_TOKEN is required")
    if PROJECT_REF not in ALLOWED:
        die(f"refusing non-destiny-os project ref: {PROJECT_REF}")
    paths = [Path(p) for p in sys.argv[1:]]
    if not paths:
        die("pass one or more .sql files")
    for path in paths:
        if not path.is_file():
            die(f"missing file: {path}")
        sql = path.read_text(encoding="utf-8")
        print(f"Applying {path} ({len(sql)} chars)")
        apply_sql(sql, str(path))


if __name__ == "__main__":
    main()
