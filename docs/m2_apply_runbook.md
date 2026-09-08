# M2 apply runbook (destiny-os only)

Target: **xchddfpfzrzhlbbmyhyn** — never Wanzwei.

**Flutter inventory API** already avoids live bymapara (PostgREST → Storage catalog → bundled asset).  
**Remaining M2 work** is remote schema/rows/media on destiny-os.

## Option A — New Cloud Agent run with secrets (preferred)

1. Add environment secrets: `SUPABASE_SERVICE_ROLE_KEY`, `DESTINY_SUPABASE_ANON_KEY`, `SUPABASE_ACCESS_TOKEN`
2. **Start a new agent** on `cursor/m2-destiny-backend-migration-194a` (or this apply branch) — mid-run secret adds may not inject
3. Agent runs the one-shot:

```bash
export SUPABASE_URL=https://xchddfpfzrzhlbbmyhyn.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=...
export SUPABASE_ACCESS_TOKEN=...
export DESTINY_SUPABASE_ANON_KEY=...
bash scripts/apply_m2_remote.sh
# schema + snapshot upsert (manifest→destiny-media paths) + staged media
# + catalog.json + asset catalog sync + verify counts/media/sensitive deny
```

If schema was already pasted in SQL Editor:

```bash
DESTINY_SKIP_SCHEMA=1 bash scripts/apply_m2_remote.sh
```

## Option B — GitHub Actions

Workflow: `.github/workflows/m2-destiny-supabase-apply.yml`

**Note:** GitHub only lists `workflow_dispatch` workflows that exist on the **default branch**. Merge/copy this workflow to `main` (or run via API with `--ref`) before using the Actions UI.

Repo Actions secrets: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_SERVICE_ROLE_KEY`, optional `DESTINY_SUPABASE_ANON_KEY`.  
Then: Actions → **M2 Destiny Supabase apply** → Run workflow (branch = this PR).

Actions uses the repo snapshot + optional live media download (`DESTINY_MIGRATE_MEDIA`) and uploads `inventory/catalog.json`. For WebP-staged media, prefer Option A with the local `.m2_staging` tarball.

## Option C — Dashboard SQL (+ optional media)

1. SQL Editor: paste `supabase/migrations/20260908143000_destiny_inventory_schema.sql`
2. SQL Editor: paste `supabase/migrations/20260908170000_destiny_media_storage_policies.sql`
3. SQL Editor: paste `supabase/seed/inventory_seed_owned_media.sql` **or** `inventory_seed.sql`
4. Storage → `destiny-media`:
   - Upload `supabase/seed/destiny_inventory_catalog.json` as `inventory/catalog.json`
   - Upload inventory images under `tours/`, `stays/`, `vehicles/`, `awards/` (object keys match `supabase/seed/media_manifest.json`)
   - Or run `python3 scripts/upload_staged_media.py` with `SUPABASE_SERVICE_ROLE_KEY`
5. Put `DESTINY_SUPABASE_ANON_KEY` in a new agent env and run `python3 scripts/verify_m2_remote.py`

## Option D — Sign into Supabase on agent desktop

Open the agent VM desktop / VNC, sign into https://supabase.com/dashboard (login page is often already open), then tell the agent you are logged in so it can apply SQL and copy the publishable anon key (never paste `service_role` into chat if avoidable — use env secrets).

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

- Confirm `docs/m2_data_migration_report.md` upserted counts
- Mark media rows migrated in `docs/destiny_media_inventory.md`
- Set `docs/m2_status.md` criteria to live-verified
- Keep bookings/profiles/docs on bymapara until auth bridge
