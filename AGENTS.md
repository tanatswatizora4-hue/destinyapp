# Agent instructions — Destiny M2 branch

Branch: `cursor/m2-destiny-backend-migration-194a`  
Target: Supabase project **`xchddfpfzrzhlbbmyhyn` only** (never Wanzwei).

## Current mode — EXTERNAL_ACTION_REQUIRED

Do **not** run `supabase login`, SSO/OTP, VNC credential polling, or request `service_role`.

Schema is applied by the external operator. Agent prepares artifacts only:

```bash
python3 scripts/generate_m2_operator_artifacts.py
# → scripts/generated/m2_inventory_seed.sql
# → scripts/generated/m2_media_manifest.json
```

External Supabase operator must execute the seed SQL and perform media transfer.

Flutter public reads use publishable/anon via:

```bash
--dart-define=DESTINY_SUPABASE_ANON_KEY=<publishable-or-anon-key>
```

Inventory chain: Supabase PostgREST → Storage catalog → asset catalog.  
Legacy image fallback until `DESTINY_INVENTORY_MEDIA_LIVE=true`.

Never paste secrets into chat. Never target Wanzwei. Preserve `devBypassAuth` and Firebase Auth. Do not weaken RLS.
