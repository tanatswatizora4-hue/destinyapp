# Agent instructions — Destiny

## Active milestone: M3A secure customer backend

Branch pattern: `cursor/m3-secure-customer-backend-194a`  
Supabase target: **`xchddfpfzrzhlbbmyhyn` only** (never Wanzwei).

M2 inventory cutover is complete. Do not re-seed inventory or poll credentials for M2.

M3A uses:
- Firebase Auth (keep) + Firebase ID tokens
- Edge Function `customer-api` (server verifies token → service_role DB)
- No anon write policies on sensitive tables
- No Travelport / payments yet

Deploy steps: `docs/m3a_deploy_runbook.md`  
Status: `docs/m3_status.md`

Never embed `service_role` in Flutter. Preserve `devBypassAuth` unless asked. Do not start M3B+ automatically.
