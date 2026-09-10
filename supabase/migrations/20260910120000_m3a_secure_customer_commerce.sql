-- M3A: Secure customer commerce schema (forward-only).
-- Does NOT add anon/authenticated write policies on sensitive tables.
-- Writes go through Edge Functions using service_role after Firebase ID
-- token verification. RLS remains deny-by-default for client roles.

-- ---------------------------------------------------------------------------
-- Booking lifecycle + price separation
-- ---------------------------------------------------------------------------
alter table public.bookings
  add column if not exists status text not null default 'submitted';

alter table public.bookings
  add column if not exists requested_total numeric(12, 2);

alter table public.bookings
  add column if not exists quoted_total numeric(12, 2);

alter table public.bookings
  add column if not exists customer_notes text not null default '';

alter table public.bookings
  add column if not exists cancellation_reason text;

alter table public.bookings
  add column if not exists cancelled_at timestamptz;

alter table public.bookings
  add column if not exists currency_requested text not null default 'USD';

-- Backfill requested_total from legacy total_price where empty.
update public.bookings
set requested_total = total_price
where requested_total is null;

-- Constrain lifecycle status (drop prior check if re-applied).
alter table public.bookings drop constraint if exists bookings_status_check;
alter table public.bookings
  add constraint bookings_status_check
  check (status in (
    'draft',
    'submitted',
    'quoted',
    'awaiting_payment',
    'confirmed',
    'cancelled',
    'completed'
  ));

alter table public.bookings drop constraint if exists bookings_item_type_check;
alter table public.bookings
  add constraint bookings_item_type_check
  check (item_type in ('tour', 'accommodation', 'stay', 'vehicle', 'flight'));

alter table public.bookings drop constraint if exists bookings_payment_status_check;
alter table public.bookings
  add constraint bookings_payment_status_check
  check (payment_status in (
    'none',
    'pending',
    'awaiting_payment',
    'paid',
    'refunded',
    'failed'
  ));

-- Ownership index (server filters by verified firebase_uid).
create index if not exists bookings_firebase_uid_created_idx
  on public.bookings (firebase_uid, created_at desc);

create index if not exists bookings_status_idx
  on public.bookings (status);

-- ---------------------------------------------------------------------------
-- Enquiry lifecycle
-- ---------------------------------------------------------------------------
alter table public.enquiries
  add column if not exists customer_profile_id uuid
    references public.customer_profiles (id) on delete set null;

alter table public.enquiries drop constraint if exists enquiries_status_check;
alter table public.enquiries
  add constraint enquiries_status_check
  check (status in (
    'received',
    'in_review',
    'quoted',
    'converted',
    'closed'
  ));

create index if not exists enquiries_firebase_uid_created_idx
  on public.enquiries (firebase_uid, created_at desc);

create index if not exists enquiries_status_idx
  on public.enquiries (status);

-- ---------------------------------------------------------------------------
-- Customer profiles: require firebase_uid for new secure rows
-- ---------------------------------------------------------------------------
-- Only enforce NOT NULL when the column has no nulls (fresh / empty tables).
do $$
begin
  if not exists (
    select 1 from public.customer_profiles where firebase_uid is null
  ) then
    alter table public.customer_profiles
      alter column firebase_uid set not null;
  end if;
end $$;

create index if not exists customer_profiles_email_idx
  on public.customer_profiles (email);

-- ---------------------------------------------------------------------------
-- RLS: keep enabled; NO new policies for anon/authenticated.
-- Explicit comments for operators.
-- ---------------------------------------------------------------------------
comment on table public.customer_profiles is
  'M3A: profile rows owned by firebase_uid. Client roles have no policies; Edge Function (service_role) after Firebase ID token verify.';

comment on table public.enquiries is
  'M3A: enquiry lifecycle received|in_review|quoted|converted|closed. Ownership = verified firebase_uid only.';

comment on table public.bookings is
  'M3A: booking requests. status=lifecycle; requested_total=customer estimate; quoted_total=authoritative (agent/server). No client writes.';

comment on column public.bookings.requested_total is
  'Customer-facing estimate only. Never treat as payment authority.';

comment on column public.bookings.quoted_total is
  'Authoritative quoted amount. Set only by trusted server/agent flows (M3B).';

comment on column public.bookings.total_price is
  'Legacy display column. M3A mirrors requested_total on create; prefer quoted_total when present.';
