#!/usr/bin/env python3
"""Bootstrap Destiny project API keys from SUPABASE_ACCESS_TOKEN.

Fetches anon + service_role (or publishable + secret) via Management API
for project xchddfpfzrzhlbbmyhyn only. Used when service_role / anon are
not already in the environment.

Usage (bash):
  eval "$(python3 scripts/m2_bootstrap_keys.py --export)"

Never prints key material unless --export (for shell eval) or --check
(which prints only which roles were resolved, not values).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

ALLOWED_REF = "xchddfpfzrzhlbbmyhyn"
API = "https://api.supabase.com/v1/projects/{ref}/api-keys?reveal=true"


def die(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def fetch_keys(token: str, ref: str) -> list[dict]:
    if ref != ALLOWED_REF:
        die(f"refusing non-destiny-os project ref: {ref}")
    req = urllib.request.Request(
        API.format(ref=ref),
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = resp.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        die(f"Management API api-keys HTTP {exc.code}: {detail[:300]}")
    data = json.loads(body)
    if not isinstance(data, list):
        die("unexpected api-keys response (expected list)")
    return data


def pick_key(items: list[dict], *, prefer_names: tuple[str, ...], prefer_types: tuple[str, ...]) -> str | None:
    """Return first revealed api_key matching preferred name or type."""
    by_name: dict[str, str] = {}
    by_type: dict[str, str] = {}
    for item in items:
        if not isinstance(item, dict):
            continue
        value = (
            item.get("api_key")
            or item.get("apiKey")
            or item.get("key")
            or ""
        )
        value = str(value).strip()
        if not value:
            continue
        name = str(item.get("name") or "").strip().lower()
        typ = str(item.get("type") or "").strip().lower()
        if name:
            by_name[name] = value
        if typ:
            by_type[typ] = value
    for name in prefer_names:
        if name in by_name:
            return by_name[name]
    for typ in prefer_types:
        if typ in by_type:
            return by_type[typ]
    return None


def resolve(token: str, ref: str) -> tuple[str, str]:
    items = fetch_keys(token, ref)
    service = pick_key(
        items,
        prefer_names=("service_role", "service role", "default"),
        prefer_types=("service_role", "secret"),
    )
    anon = pick_key(
        items,
        prefer_names=("anon", "anonymous", "default"),
        prefer_types=("anon", "publishable"),
    )
    # Prefer explicit service_role type over a generic "default" secret name miss.
    if not service:
        # Second pass: any type containing service/secret
        for item in items:
            typ = str(item.get("type") or "").lower()
            name = str(item.get("name") or "").lower()
            value = str(item.get("api_key") or item.get("apiKey") or item.get("key") or "").strip()
            if value and ("service" in typ or typ == "secret" or name == "service_role"):
                service = value
                break
    if not anon:
        for item in items:
            typ = str(item.get("type") or "").lower()
            name = str(item.get("name") or "").lower()
            value = str(item.get("api_key") or item.get("apiKey") or item.get("key") or "").strip()
            if value and (typ in ("anon", "publishable") or name == "anon"):
                anon = value
                break
    if not service:
        die("could not resolve service_role/secret key from Management API")
    if not anon:
        die("could not resolve anon/publishable key from Management API")
    return service, anon


def shell_quote(value: str) -> str:
    return "'" + value.replace("'", "'\"'\"'") + "'"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--export",
        action="store_true",
        help="Print bash export lines for missing keys (for eval)",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Resolve keys and print roles found (no secret values)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing SERVICE_ROLE / ANON env values",
    )
    args = parser.parse_args()

    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "").strip()
    if not token:
        die("SUPABASE_ACCESS_TOKEN is required to bootstrap project API keys")
    ref = os.environ.get("SUPABASE_PROJECT_REF", ALLOWED_REF).strip() or ALLOWED_REF

    need_service = args.force or not os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    need_anon = args.force or not os.environ.get("DESTINY_SUPABASE_ANON_KEY", "").strip()

    if not need_service and not need_anon and not args.check:
        if args.export:
            print("# m2_bootstrap_keys: service_role and anon already set")
        else:
            print("OK already have SUPABASE_SERVICE_ROLE_KEY and DESTINY_SUPABASE_ANON_KEY")
        return

    service, anon = resolve(token, ref)

    if args.check:
        print(f"OK resolved keys for {ref} (service_role=yes anon=yes)")
        return

    if args.export:
        if need_service:
            print(f"export SUPABASE_SERVICE_ROLE_KEY={shell_quote(service)}")
        if need_anon:
            print(f"export DESTINY_SUPABASE_ANON_KEY={shell_quote(anon)}")
        print("# m2_bootstrap_keys: exported missing Destiny API keys")
        return

    # Default: set in current process only useful if imported; instruct eval.
    print(
        "Run: eval \"$(python3 scripts/m2_bootstrap_keys.py --export)\"",
        file=sys.stderr,
    )
    sys.exit(2)


if __name__ == "__main__":
    main()
