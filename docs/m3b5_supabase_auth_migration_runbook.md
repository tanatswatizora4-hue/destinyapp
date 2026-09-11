# M3B.5 Supabase Auth migration runbook

Project: `xchddfpfzrzhlbbmyhyn`  
Do not deploy to Wanzwei. Do not paste service_role or passwords into tickets.

## 1. Database migration

```bash
supabase db push --project-ref xchddfpfzrzhlbbmyhyn
# or apply:
# supabase/migrations/20260911090000_m3b5_supabase_auth_identity.sql
```

Adds `user_id` / `actor_user_id` / staff assignment UUID columns. Keeps
`firebase_uid` as nullable legacy.

## 2. Edge Function deploy

```bash
supabase functions deploy customer-api --project-ref xchddfpfzrzhlbbmyhyn
supabase functions deploy staff-commerce-api --project-ref xchddfpfzrzhlbbmyhyn
```

## 3. verify_jwt

Both functions use **`verify_jwt = true`**.

Gateway rejects non-Supabase JWTs. Functions still call `auth.getUser(token)`
and derive `user_id` server-side. Never trust body `user_id` / `role`.

`FIREBASE_PROJECT_ID` is obsolete — may be removed from secrets after cutover.

## 4. Supabase Auth settings

Dashboard → Authentication:

- Enable **Email** provider (password)
- Decide email confirmation (recommended for production)
- Site URL = production app origin
- Do **not** require the old Firebase project

Google OAuth is **deferred** (not required for M3B.5 baseline).

## 5. Password-reset redirect URLs

Allowlist in Auth → URL Configuration:

- Production web origin + `/auth/reset` (or the deep-link you wire)
- Local/dev origins as needed
- Override in Flutter with
  `--dart-define=DESTINY_PASSWORD_RESET_REDIRECT=https://YOUR_HOST/auth/reset`

Default placeholder in code: `https://destinyos.local/auth/reset` (must be replaced
for production).

## 6. Email verification

If “Confirm email” is on:

- Sign-up returns session only after confirm (or magic link)
- Login copy already mentions confirmation when required

## 7. First customer user

1. Open the app → Sign Up with a real email/password
2. Confirm email if required
3. Sign in
4. App upserts `customer_profiles` via `customer-api` (`user_id` from token)

Existing Firebase-only users: **create a new Destiny account** (clean reset).

## 8. First staff admin seed

1. Create/sign in the admin as a normal Supabase Auth user (step 7)
2. Copy their UUID from Authentication → Users (`auth.users.id`)
3. Run operator SQL (replace placeholders — never invent UUIDs):

```sql
insert into public.staff_users (
  user_id,
  email,
  display_name,
  role,
  is_active
)
values (
  'REAL_SUPABASE_AUTH_USER_UUID',
  'REAL_EMAIL',
  'Tan',
  'admin',
  true
)
on conflict (user_id) do update
set
  email = excluded.email,
  display_name = excluded.display_name,
  role = excluded.role,
  is_active = true;
```

Roles: `consultant` | `manager` | `admin`. Authorization is by `user_id`, not email.

## 9. Smoke tests

1. Unauthenticated: browse Home/Tours/Stays/Vehicles/Flights OK
2. Unauthenticated: booking submit fails (sign-in required / API 401)
3. Sign up → profile upsert → create booking request → appears in My Bookings
4. Flight enquiry → My Trips
5. Non-staff signed-in user → `/staff-ops` → 403
6. Seeded admin → staff_me OK → quote booking → customer sees quote
7. Password reset email delivers to allowlisted redirect

## 10. Rollback / recovery

- Code rollback: redeploy previous function bundle + Flutter build (Firebase Auth
  returns only if that build still exists — **not recommended**; Destiny does not
  control the old Firebase project).
- DB: `user_id` columns are additive; leaving them in place is safe.
- Do not drop `firebase_uid` until a later cleanup milestone.
- If Auth misconfigured: fix redirect URLs / email templates before seeding staff.

## Operator SQL template file

See also comments in migration + `docs/m3b5_security_review.md`.
