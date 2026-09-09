# M2 Actions enablement (default branch)

This PR registers `.github/workflows/m2-destiny-supabase-apply.yml` on `main` so GitHub shows **workflow_dispatch**.

## How to run

1. Add repo Actions secret **`SUPABASE_ACCESS_TOKEN`** (Supabase PAT for destiny-os). Optional: `SUPABASE_SERVICE_ROLE_KEY`, `DESTINY_SUPABASE_ANON_KEY` (bootstrapped from the PAT when omitted).
2. Actions → **M2 Destiny Supabase apply** → Run workflow.
3. **Branch:** `cursor/m2-destiny-backend-migration-194a` (required — scripts + LFS media live there).
4. Leave `migrate_media` enabled. Leave `redownload_legacy_media` off.

## Guards

- Checkout uses `lfs: true`; extract fails on LFS pointers and requires ≥81 staged files.
- After verify (when anon key is set), workflow runs `m2_finalize_docs.py`.

Do not target Wanzwei. Never put `service_role` in the Flutter app.
