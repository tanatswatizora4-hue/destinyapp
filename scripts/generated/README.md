# M2 operator artifacts (historical)

Target project: `xchddfpfzrzhlbbmyhyn` only.

**Live apply is complete.** These files remain for schema parity / regeneration.
Do not re-seed or re-upload unless intentionally refreshing production.

## Files

- `m2_inventory_seed.sql` — idempotent inventory upsert (includes WebP path corrections)
- `m2_media_manifest.json` — legacy → destiny-media transfer map
- `m2_source_audit.json` — source counts / seed counts

Verified live: tours/stays/vehicles/awards = 25/36/3/6; 81 destiny-media files.  
`inventory/catalog.json` is **not** required for M2 completion.

Regenerate (offline / refresh only): `python3 scripts/generate_m2_operator_artifacts.py`
