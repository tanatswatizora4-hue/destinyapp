-- M3B.5 first staff admin seed
-- Replace placeholders with a REAL row from Authentication → Users.
-- Never invent a UUID. Authorization is by user_id, not email.

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
  is_active = true,
  updated_at = timezone('utc', now());
