# M3B.5 security review

Date: 2026-09-11  
Branch: `cursor/m3b5-supabase-auth-migration-194a`

## Findings

| Check | Result |
|-------|--------|
| `FirebaseAuth` / `firebase_auth` runtime | **Removed** from Flutter deps and screens |
| `FIREBASE_PROJECT_ID` / Firebase JWKS verify | **Removed** from Edge Functions |
| `firebase_uid` as authority | **No** — ownership/allowlist use `user_id` |
| Client-supplied `user_id` / `role` | **Rejected** in customer + staff clients and Edge assert helpers |
| `service_role` in Flutter | **Not present** |
| Authenticated write policies on commerce/staff | **None** (RLS MODEL A) |
| Staff auth by email alone | **No** — `staff_users.user_id` + `is_active` |
| Protected customer routes | Nav indices 5–8 gated; APIs require token |
| `devBypassAuth` | UI browsing only; **does not** bypass Edge authorization |

## Residual legacy (non-authoritative)

- DB columns: `firebase_uid`, `actor_firebase_uid`, `assigned_staff_uid`, `quoted_by_uid`
- Files: `android/**/google-services.json`, `lib/firebase_options.dart` (unused; safe to delete later)
- bymapara: Travel Docs / photo upload / `syncUserWithSql` still called with Supabase UUID string

## Google OAuth

Deferred. Email/password is the baseline. Do not reintroduce Firebase Google Sign-In.

## Verdict

Auth ownership migration meets M3B.5 security constraints for code review.
Live cutover still requires migration apply, function deploy, Auth URL config,
and first-admin seed with a **real** `auth.users` UUID.
