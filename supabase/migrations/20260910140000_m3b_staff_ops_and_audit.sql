-- M3B: Staff authorization, quoting fields, audit events, enquiry linkage.
-- Forward-only. No anon/authenticated write policies on sensitive tables.

-- ---------------------------------------------------------------------------
-- Staff allowlist (server-checked; no public policies)
-- ---------------------------------------------------------------------------
create table if not exists public.staff_users (
  id uuid primary key default gen_random_uuid(),
  firebase_uid text not null unique,
  email text not null default '',
  display_name text not null default '',
  role text not null default 'consultant'
    check (role in ('consultant', 'manager', 'admin')),
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists staff_users_active_role_idx
  on public.staff_users (is_active, role);

drop trigger if exists staff_users_set_updated_at on public.staff_users;
create trigger staff_users_set_updated_at
  before update on public.staff_users
  for each row execute function public.set_updated_at();

alter table public.staff_users enable row level security;
-- Intentionally no policies: deny-by-default for anon/authenticated.

comment on table public.staff_users is
  'M3B: Destiny staff allowlist. Edge Function checks firebase_uid + is_active after Firebase ID token verify. Seed via privileged SQL only.';

-- ---------------------------------------------------------------------------
-- Booking quote / assignment / enquiry linkage
-- ---------------------------------------------------------------------------
alter table public.bookings
  add column if not exists quote_expires_at timestamptz;

alter table public.bookings
  add column if not exists customer_quote_note text not null default '';

alter table public.bookings
  add column if not exists internal_notes text not null default '';

alter table public.bookings
  add column if not exists assigned_staff_uid text;

alter table public.bookings
  add column if not exists enquiry_id uuid
    references public.enquiries (id) on delete set null;

alter table public.bookings
  add column if not exists quoted_at timestamptz;

alter table public.bookings
  add column if not exists quoted_by_uid text;

create index if not exists bookings_enquiry_id_idx
  on public.bookings (enquiry_id);

create index if not exists bookings_assigned_staff_uid_idx
  on public.bookings (assigned_staff_uid);

-- ---------------------------------------------------------------------------
-- Enquiry assignment / customer-facing response
-- ---------------------------------------------------------------------------
alter table public.enquiries
  add column if not exists assigned_staff_uid text;

alter table public.enquiries
  add column if not exists customer_response_note text not null default '';

alter table public.enquiries
  add column if not exists internal_notes text not null default '';

alter table public.enquiries
  add column if not exists converted_booking_id uuid
    references public.bookings (id) on delete set null;

create index if not exists enquiries_assigned_staff_uid_idx
  on public.enquiries (assigned_staff_uid);

-- ---------------------------------------------------------------------------
-- Immutable booking audit trail
-- ---------------------------------------------------------------------------
create table if not exists public.booking_events (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete cascade,
  event_type text not null,
  previous_status text,
  new_status text,
  actor_type text not null
    check (actor_type in ('customer', 'staff', 'system')),
  actor_firebase_uid text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists booking_events_booking_created_idx
  on public.booking_events (booking_id, created_at desc);

alter table public.booking_events enable row level security;

comment on table public.booking_events is
  'M3B: append-only booking audit. Written only by Edge Functions (service_role). No public policies.';

-- ---------------------------------------------------------------------------
-- Enquiry audit trail
-- ---------------------------------------------------------------------------
create table if not exists public.enquiry_events (
  id uuid primary key default gen_random_uuid(),
  enquiry_id uuid not null references public.enquiries (id) on delete cascade,
  event_type text not null,
  previous_status text,
  new_status text,
  actor_type text not null
    check (actor_type in ('customer', 'staff', 'system')),
  actor_firebase_uid text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists enquiry_events_enquiry_created_idx
  on public.enquiry_events (enquiry_id, created_at desc);

alter table public.enquiry_events enable row level security;

comment on table public.enquiry_events is
  'M3B: append-only enquiry audit. Edge Function writes only.';

-- ---------------------------------------------------------------------------
-- Operator seed template (DO NOT invent UIDs — fill after deploy)
-- ---------------------------------------------------------------------------
-- insert into public.staff_users (firebase_uid, email, display_name, role, is_active)
-- values ('FIREBASE_UID_HERE', 'consultant@example.com', 'Destiny Consultant', 'consultant', true)
-- on conflict (firebase_uid) do update
--   set email = excluded.email,
--       display_name = excluded.display_name,
--       role = excluded.role,
--       is_active = excluded.is_active,
--       updated_at = timezone('utc', now());
