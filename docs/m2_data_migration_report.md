# M2 data migration report

**Status:** BLOCKED — awaiting Supabase credentials  
**Date audited:** 2026-09-08  
**Source:** `https://bymapara.com/destiny_api.php`  
**Target:** `https://xchddfpfzrzhlbbmyhyn.supabase.co`  
**Tool:** `scripts/migrate_inventory_to_supabase.py`

## Live legacy source counts (audited)

| Entity | Source action | Count |
|--------|---------------|------:|
| Tours | `get_tours` | 25 |
| Stays | `get_accommodations` | 36 |
| Vehicles | `get_vehicles` | 3 |
| Awards | `get_awards` | 6 |

## Migrated counts

| Entity | Source | Upserted | Skipped | Notes |
|--------|-------:|---------:|--------:|-------|
| Tours | 25 | — | — | Not applied — no `SUPABASE_SERVICE_ROLE_KEY` |
| Stays | 36 | — | — | Not applied |
| Vehicles | 3 | — | — | Not applied |
| Awards | 6 | — | — | Not applied |

Media uploaded: **n/a**  
Media failed: **n/a**  
Media missing: **n/a**

## Idempotency

- Parent rows upsert on `legacy_id` (unique)
- Child rows deleted + reinserted per parent UUID on each run
- Optional media copy: `DESTINY_MIGRATE_MEDIA=1`

## Required to complete

```bash
export SUPABASE_URL=https://xchddfpfzrzhlbbmyhyn.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=<service_role from destiny-os project>
# Apply schema first (SQL Editor or supabase db push linked to xchddfpfzrzhlbbmyhyn)
python3 scripts/migrate_inventory_to_supabase.py
DESTINY_MIGRATE_MEDIA=1 python3 scripts/migrate_inventory_to_supabase.py
```

Flutter cutover additionally needs publishable:

```bash
--dart-define=DESTINY_SUPABASE_ANON_KEY=<anon key>
```

## Malformed / skipped

- none yet (migration not executed against target)
