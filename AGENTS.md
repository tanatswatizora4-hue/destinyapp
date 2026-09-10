# Agent instructions — Destiny

## Active milestone: M3B booking lifecycle + staff ops

Branch: `cursor/m3b-booking-operations-194a`  
Supabase: **`xchddfpfzrzhlbbmyhyn` only** (never Wanzwei).

- Customer path: `customer-api` (unchanged security model)
- Staff path: `staff-commerce-api` + `staff_users` allowlist
- Deploy: `docs/m3b_deploy_runbook.md`
- Status: `docs/m3_status.md`

Do not invent staff Firebase UIDs. Do not start Travelport/payments.
Never embed `service_role` in Flutter. Preserve `devBypassAuth` unless asked.
