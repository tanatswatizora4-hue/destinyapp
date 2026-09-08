# M2 apply runbook (destiny-os only)

Target: **xchddfpfzrzhlbbmyhyn** — never Wanzwei.

**Flutter inventory API** already avoids live bymapara (PostgREST → Storage catalog → bundled asset).  
**Remaining M2 work** is remote schema/rows/media on destiny-os.

## Option A — New Cloud Agent run with secrets (preferred)

**Minimum:** one Personal Access Token (`SUPABASE_ACCESS_TOKEN`) with access to destiny-os.  
`apply_m2_remote.sh` bootstraps `service_role` + anon from the Management API when those are unset.

1. Create a PAT at https://supabase.com/dashboard/account/tokens (include API Keys read + SQL/database permissions needed for schema apply)
2. Add environment secret: `SUPABASE_ACCESS_TOKEN` (optionally also `SUPABASE_SERVICE_ROLE_KEY` / `DESTINY_SUPABASE_ANON_KEY`)
3. **Start a new agent** on `cursor/m2-destiny-backend-migration-194a` — mid-run secret adds may not inject
4. Agent runs:

```bash
export SUPABASE_URL=https://xchddfpfzrzhlbbmyhyn.supabase.co
export SUPABASE_ACCESS_TOKEN=...   # sufficient alone
bash scripts/apply_m2_remote.sh
# schema + snapshot upsert + staged media + catalog.json + verify + doc finalize
```

If schema was already pasted in SQL Editor:

```bash
DESTINY_SKIP_SCHEMA=1 bash scripts/apply_m2_remote.sh
```

## Option B — GitHub Actions

Workflow: `.github/workflows/m2-destiny-supabase-apply.yml`

**Note:** GitHub only lists `workflow_dispatch` workflows on the **default branch**. PR #13 (`cursor/m2-gha-enable-194a` → `main`) registers the workflow; when running, select branch **`cursor/m2-destiny-backend-migration-194a`** (scripts + Git LFS media live there).

Repo Actions secret **required:** `SUPABASE_ACCESS_TOKEN`.  
Optional: `SUPABASE_SERVICE_ROLE_KEY`, `DESTINY_SUPABASE_ANON_KEY` (bootstrapped from the PAT when omitted).  
Then: Actions → **M2 Destiny Supabase apply** → Run workflow.

The workflow checks out with `lfs: true`, fails if the media tarball is still an LFS pointer, extracts ≥81 staged files, upserts inventory, uploads owned paths + `inventory/catalog.json`, then verifies when anon key is set.

## Option C — Dashboard SQL (+ optional media)

1. SQL Editor: paste `supabase/migrations/20260908143000_destiny_inventory_schema.sql`
2. SQL Editor: paste `supabase/migrations/20260908170000_destiny_media_storage_policies.sql`
3. Prefer PostgREST migrator (`migrate_inventory_to_supabase.py`) over SQL seed. If pasting seed SQL, use **only** `inventory_seed_owned_media.sql` (LF). Do **not** apply historical `inventory_seed.sql` for cutover — it writes legacy `uploads/` primary paths and fails owned-path verify.
4. Storage → `destiny-media`:
   - Upload `supabase/seed/destiny_inventory_catalog.json` as `inventory/catalog.json`
   - Upload inventory images under `tours/`, `stays/`, `vehicles/`, `awards/` (object keys match `supabase/seed/media_manifest.json`)
   - Or run `python3 scripts/upload_staged_media.py` with `SUPABASE_SERVICE_ROLE_KEY`
5. Put `DESTINY_SUPABASE_ANON_KEY` in a new agent env and run `python3 scripts/verify_m2_remote.py`

## Option D — Sign into Supabase on agent desktop / CLI login

Open the agent VM desktop / VNC, sign into https://supabase.com/dashboard, authorize the CLI login waiting in tmux `sb-login` (enter the verification code), then tell the agent “login done”.

`apply_m2_remote.sh` auto-loads `SUPABASE_ACCESS_TOKEN` from `~/.supabase/access-token` when the env var is unset (after a successful `supabase login`). Do not paste tokens into chat.

## Expected counts

| Entity | Count |
|--------|------:|
| Tours | 25 |
| Stays | 36 |
| Vehicles | 3 |
| Awards | 6 |
| Media staged locally | 81 / 84 (also in repo via Git LFS tarball) |
| Media missing (legacy 404) | 3 |

After remote verify, run Flutter with owned inventory media live:

```bash
--dart-define=DESTINY_INVENTORY_MEDIA_LIVE=true
--dart-define=DESTINY_SUPABASE_ANON_KEY=<publishable anon key>
```

(Until then, inventory `destiny-media/tours|stays|vehicles|awards` refs resolve through the legacy upload map so images keep working.)
