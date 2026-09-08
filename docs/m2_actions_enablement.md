# M2 Actions enablement (default branch)

This PR registers `.github/workflows/m2-destiny-supabase-apply.yml` on `main` so GitHub shows **workflow_dispatch**.

## How to run

1. Add repo Actions secrets: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_SERVICE_ROLE_KEY`, optional `DESTINY_SUPABASE_ANON_KEY` (destiny-os / `xchddfpfzrzhlbbmyhyn` only).
2. Actions → **M2 Destiny Supabase apply** → Run workflow.
3. **Branch:** `cursor/m2-destiny-backend-migration-194a` (required — scripts + LFS media live there).
4. Leave `migrate_media` enabled.

## LFS / media guards

Checkout uses `lfs: true`. The extract step fails if the media tarball is still a Git LFS pointer, and requires ≥81 staged files before upload.

Do not target Wanzwei. Never put `service_role` in the Flutter app.
