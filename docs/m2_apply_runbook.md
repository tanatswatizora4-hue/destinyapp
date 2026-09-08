# M2 apply runbook (destiny-os only)

Target: **xchddfpfzrzhlbbmyhyn** — never Wanzwei.

**Flutter inventory API** already avoids live bymapara (PostgREST → Storage catalog → bundled asset).  
**Remaining M2 work** is remote schema/rows/media on destiny-os.

## Option A — New Cloud Agent run with secrets (preferred)

1. Add environment secrets: `SUPABASE_SERVICE_ROLE_KEY`, `DESTINY_SUPABASE_ANON_KEY`, optional `SUPABASE_ACCESS_TOKEN`
2. **Start a new agent** on `cursor/m2-destiny-backend-migration-194a` (mid-run secret adds may not inject)
3. Agent runs:

```bash
export SUPABASE_URL=https://xchddfpfzrzhlbbmyhyn.supabase.co
python3 scripts/apply_sql_management_api.py \
  supabase/migrations/20260908143000_destiny_inventory_schema.sql
DESTINY_MIGRATE_MEDIA=1 python3 scripts/migrate_inventory_to_supabase.py
# verify anon reads, update docs/m2_data_migration_report.md, flutter test
```

## Option B — GitHub Actions

Workflow: `.github/workflows/m2-destiny-supabase-apply.yml` on this branch.

Repo Actions secrets: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_SERVICE_ROLE_KEY`, optional `DESTINY_SUPABASE_ANON_KEY`.  
Then: Actions → **M2 Destiny Supabase apply** → Run workflow.

## Option C — Dashboard SQL (+ optional media)

1. SQL Editor: paste `supabase/migrations/20260908143000_destiny_inventory_schema.sql`
2. SQL Editor: paste `supabase/seed/inventory_seed_owned_media.sql` **or** `inventory_seed.sql`
3. Storage → `destiny-media`:
   - Upload `supabase/seed/destiny_inventory_catalog.json` as `inventory/catalog.json`
   - Upload inventory images under `tours/`, `stays/`, `vehicles/`, `awards/` (object keys match `supabase/seed/media_manifest.json`)
4. Put `DESTINY_SUPABASE_ANON_KEY` in a new agent env and verify PostgREST reads

## Expected counts

| Entity | Count |
|--------|------:|
| Tours | 25 |
| Stays | 36 |
| Vehicles | 3 |
| Awards | 6 |
| Media staged locally | 81 / 84 |
| Media missing (legacy 404) | 3 |

## After remote verify

- Update `docs/m2_data_migration_report.md` with upserted counts
- Mark media rows migrated in `docs/destiny_media_inventory.md`
- Keep bookings/profiles/docs on bymapara until auth bridge
