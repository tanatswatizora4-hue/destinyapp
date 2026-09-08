# M2 apply runbook (destiny-os only)

Target: **xchddfpfzrzhlbbmyhyn** — never Wanzwei.

## Option A — Cursor agent (preferred when secrets are in the Cloud Agent env)

```bash
export SUPABASE_URL=https://xchddfpfzrzhlbbmyhyn.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=...   # Dashboard → Project Settings → API
export DESTINY_SUPABASE_ANON_KEY=...   # publishable anon / publishable key
# Optional for schema apply without SQL Editor:
export SUPABASE_ACCESS_TOKEN=...      # Dashboard → Account → Access Tokens

# Schema (pick one):
#   - SQL Editor paste: supabase/migrations/20260908143000_destiny_inventory_schema.sql
#   - OR:
python3 scripts/apply_sql_management_api.py \
  supabase/migrations/20260908143000_destiny_inventory_schema.sql

# Media + rows:
python3 scripts/upload_staged_media.py   # uses /tmp staging when present
DESTINY_MIGRATE_MEDIA=1 python3 scripts/migrate_inventory_to_supabase.py

# Verify + Flutter:
curl "$SUPABASE_URL/rest/v1/tours?select=id&limit=1" \
  -H "apikey: $DESTINY_SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $DESTINY_SUPABASE_ANON_KEY"
flutter run --dart-define=DESTINY_SUPABASE_ANON_KEY=$DESTINY_SUPABASE_ANON_KEY
```

## Option B — GitHub Actions (manual workflow_dispatch)

Workflow: `.github/workflows/m2-destiny-supabase-apply.yml`

Add repo Actions secrets:

| Secret | Purpose |
|--------|---------|
| `SUPABASE_ACCESS_TOKEN` | Management API schema apply |
| `SUPABASE_SERVICE_ROLE_KEY` | Inventory upsert + Storage upload |
| `DESTINY_SUPABASE_ANON_KEY` | Optional post-apply read verify |

Then: Actions → **M2 Destiny Supabase apply** → Run workflow (`migrate_media` on).

## Option C — Dashboard-only

1. SQL Editor: schema migration
2. SQL Editor: `supabase/seed/inventory_seed.sql` (legacy image paths OK temporarily)
3. Provide agent `DESTINY_SUPABASE_ANON_KEY` for Flutter cutover
4. Later: service_role for Storage media upload

## Expected counts

| Entity | Count |
|--------|------:|
| Tours | 25 |
| Stays | 36 |
| Vehicles | 3 |
| Awards | 6 |
| Media staged | 81 / 84 |
| Media missing (legacy 404) | 3 |

## After verify

- Mark inventory legacy PHP reads RETIRED in `docs/m2_legacy_retirement_status.md`
- Keep bookings/profiles/docs on bymapara until auth bridge
