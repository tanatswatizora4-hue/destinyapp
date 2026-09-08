#!/usr/bin/env python3
"""Unit tests for M2 migrator helpers (no network, no secrets)."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATE = ROOT / "scripts" / "migrate_inventory_to_supabase.py"


def load_migrate():
    spec = importlib.util.spec_from_file_location("migrate_inventory", MIGRATE)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    # Avoid running main; module sets SERVICE_KEY from env at import.
    spec.loader.exec_module(mod)
    return mod


class ParseJsonListTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m = load_migrate()

    def test_list_passthrough(self):
        self.assertEqual(self.m.parse_json_list(["a", "b"]), ["a", "b"])

    def test_json_array_string(self):
        self.assertEqual(
            self.m.parse_json_list('["uploads/a.jpg"]'),
            ["uploads/a.jpg"],
        )

    def test_bare_path_string(self):
        self.assertEqual(
            self.m.parse_json_list("uploads/IMG-20250902-WA0010.jpg"),
            ["uploads/IMG-20250902-WA0010.jpg"],
        )

    def test_empty(self):
        self.assertEqual(self.m.parse_json_list(None), [])
        self.assertEqual(self.m.parse_json_list(""), [])
        self.assertEqual(self.m.parse_json_list("[]"), [])


class ManifestRemapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m = load_migrate()
        # Force reload of manifest from repo seed.
        cls.m._MANIFEST_MAP = None

    def test_manifest_maps_known_tour(self):
        owned = self.m.owned_path_for(
            "tours",
            39,
            "uploads/6a4f9a97e9470-615724801_1664832577822577_6837233941983207803_n.jpg",
        )
        self.assertEqual(owned, "destiny-media/tours/39/primary.jpg")

    def test_missing_media_not_mapped(self):
        owned = self.m.owned_path_for(
            "awards", 7, "uploads/IMG-20250902-WA0007.jpg"
        )
        self.assertIsNone(owned)

    def test_migrate_images_remaps_without_download(self):
        self.m.MIGRATE_MEDIA = False
        stats = {
            "media_uploaded": 0,
            "media_failed": 0,
            "media_missing": 0,
            "media_remapped": 0,
        }
        primary, rows = self.m.migrate_images(
            "awards",
            4,
            ["uploads/IMG-20250902-WA0010.jpg"],
            stats,
        )
        self.assertEqual(primary, "destiny-media/awards/3/primary.jpg")
        self.assertEqual(rows[0]["storage_path"], primary)
        self.assertEqual(rows[0]["legacy_url"], "uploads/IMG-20250902-WA0010.jpg")
        self.assertGreaterEqual(stats["media_remapped"], 1)


class RebuildCatalogTests(unittest.TestCase):
    def test_rebuild_awards_bare_strings(self):
        # Import rebuild helpers by exec
        path = ROOT / "scripts" / "rebuild_owned_catalog.py"
        spec = importlib.util.spec_from_file_location("rebuild_catalog", path)
        mod = importlib.util.module_from_spec(spec)
        assert spec.loader is not None
        spec.loader.exec_module(mod)
        self.assertEqual(
            mod.parse_json_list("uploads/x.jpg"),
            ["uploads/x.jpg"],
        )


class ProjectGuardTests(unittest.TestCase):
    def test_apply_sql_refuses_non_destiny(self):
        path = ROOT / "scripts" / "apply_sql_management_api.py"
        text = path.read_text(encoding="utf-8")
        self.assertIn("xchddfpfzrzhlbbmyhyn", text)
        self.assertIn("ALLOWED", text)


if __name__ == "__main__":
    unittest.main()
