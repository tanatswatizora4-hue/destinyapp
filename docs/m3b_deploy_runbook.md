# M3B deploy runbook (destiny-os only)

Project ref: **xchddfpfzrzhlbbmyhyn**  
Never target Wanzwei. Never put `service_role` in Flutter.

## 1. Apply SQL migration

Run in Destiny SQL editor (privileged):

`supabase/migrations/20260910140000_m3b_staff_ops_and_audit.sql`

Confirm tables exist:
- `staff_users` (RLS on, zero policies)
- `booking_events`, `enquiry_events` (RLS on, zero policies)
- booking columns: `quote_expires_at`, `customer_quote_note`, `internal_notes`, `enquiry_id`, …

## 2. Deploy Edge Functions

```bash
supabase functions deploy staff-commerce-api --project-ref xchddfpfzrzhlbbmyhyn
supabase functions deploy customer-api --project-ref xchddfpfzrzhlbbmyhyn
# optional (defaults to destinytravel-1a16e)
supabase secrets set FIREBASE_PROJECT_ID=destinytravel-1a16e --project-ref xchddfpfzrzhlbbmyhyn
```

Both functions use `verify_jwt = false` and verify Firebase ID tokens themselves.

## 3. Seed first staff user (required human step)

Do **not** invent UIDs. After the staff member signs into the Flutter app once:

1. Copy their Firebase Auth UID from Firebase Console → Authentication
2. Run:

```sql
insert into public.staff_users (firebase_uid, email, display_name, role, is_active)
values (
  '<FIREBASE_UID>',
  '<email>',
  '<Display Name>',
  'consultant', -- or manager | admin
  true
)
on conflict (firebase_uid) do update
set email = excluded.email,
    display_name = excluded.display_name,
    role = excluded.role,
    is_active = true,
    updated_at = timezone('utc', now());
```

## 4. Verify

1. Sign in as staff → Profile → **Destiny Operations**
2. Non-staff users see Access denied (403)
3. Quote a submitted booking → status `quoted`, `quoted_total` set, `payment_status` still not `paid`
4. Transition `quoted → awaiting_payment → confirmed`
5. Customer My Bookings shows Destiny quote panel (not “price confirmed”)
6. Convert an enquiry → booking `status=submitted` with `enquiry_id` set

## 5. Rollback notes

- Disable staff: `update staff_users set is_active=false where firebase_uid='…'`
- Functions can be undeployed; customer-api remains the customer path
- Do not add anon write policies as a “fix”
