-- M3B.5: Supabase Auth identity ownership (forward-only).
-- Canonical identity = auth.users.id as public.*.user_id
-- firebase_uid columns retained as deprecated legacy (non-authoritative).

-- ---------------------------------------------------------------------------
-- customer_profiles.user_id
-- ---------------------------------------------------------------------------
alter table public.customer_profiles
  add column if not exists user_id uuid unique references auth.users (id)
    on delete cascade;

create index if not exists customer_profiles_user_id_idx
  on public.customer_profiles (user_id);

comment on column public.customer_profiles.user_id is
  'M3B.5 canonical Supabase Auth UUID. firebase_uid is legacy/deprecated.';

comment on column public.customer_profiles.firebase_uid is
  'DEPRECATED after M3B.5. Kept for historical rows; new writes use user_id.';

-- Allow firebase_uid null for new Supabase-only profiles.
alter table public.customer_profiles alter column firebase_uid drop not null;

-- ---------------------------------------------------------------------------
-- enquiries.user_id
-- ---------------------------------------------------------------------------
alter table public.enquiries
  add column if not exists user_id uuid references auth.users (id)
    on delete set null;

create index if not exists enquiries_user_id_created_idx
  on public.enquiries (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- bookings.user_id
-- ---------------------------------------------------------------------------
alter table public.bookings
  add column if not exists user_id uuid references auth.users (id)
    on delete set null;

create index if not exists bookings_user_id_created_idx
  on public.bookings (user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- staff_users.user_id (new canonical allowlist key)
-- ---------------------------------------------------------------------------
alter table public.staff_users
  add column if not exists user_id uuid unique references auth.users (id)
    on delete cascade;

create index if not exists staff_users_user_id_active_idx
  on public.staff_users (user_id, is_active);

-- firebase_uid may become null for new staff seeded by user_id only.
alter table public.staff_users alter column firebase_uid drop not null;

comment on column public.staff_users.user_id is
  'M3B.5 canonical staff identity (Supabase Auth UUID).';

comment on column public.staff_users.firebase_uid is
  'DEPRECATED after M3B.5.';

-- ---------------------------------------------------------------------------
-- Audit actor columns
-- ---------------------------------------------------------------------------
alter table public.booking_events
  add column if not exists actor_user_id uuid references auth.users (id)
    on delete set null;

alter table public.enquiry_events
  add column if not exists actor_user_id uuid references auth.users (id)
    on delete set null;

-- Staff assignment fields as UUID (alongside legacy string UIDs)
alter table public.bookings
  add column if not exists assigned_staff_user_id uuid
    references auth.users (id) on delete set null;

alter table public.bookings
  add column if not exists quoted_by_user_id uuid
    references auth.users (id) on delete set null;

alter table public.enquiries
  add column if not exists assigned_staff_user_id uuid
    references auth.users (id) on delete set null;

-- ---------------------------------------------------------------------------
-- RLS: MODEL A — keep deny-default; no authenticated policies.
-- ---------------------------------------------------------------------------
-- staff_users / events / commerce already have RLS enabled with zero policies.

comment on table public.staff_users is
  'M3B.5 staff allowlist keyed by user_id (auth.users). Edge Function only.';
