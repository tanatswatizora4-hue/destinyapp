# M2 operator artifacts (no credentials)

Target project: `xchddfpfzrzhlbbmyhyn` only.

## Files

- `m2_inventory_seed.sql` — idempotent inventory upsert (parents + children)
- `m2_media_manifest.json` — legacy → destiny-media transfer map
- `m2_source_audit.json` — source counts / seed counts

## External action

1. Run `m2_inventory_seed.sql` in the Destiny SQL editor (privileged).
2. Upload media per `m2_media_manifest.json` into bucket `destiny-media`.
3. Confirm counts tours/stays/vehicles/awards = 25/36/3/6 and catalog.json HTTP 200.

Regenerate: `python3 scripts/generate_m2_operator_artifacts.py`
