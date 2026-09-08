-- M2 Destiny OS schema: public inventory + protected customer stubs
-- Target project: xchddfpfzrzhlbbmyhyn (destiny-os)
-- Public inventory is read-only for anon; sensitive tables have RLS with no anon policies.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tours
-- ---------------------------------------------------------------------------
create table if not exists public.tours (
  id uuid primary key default gen_random_uuid(),
  legacy_id integer unique,
  title text not null,
  description text not null default '',
  price numeric(12, 2) not null default 0,
  currency text not null default 'USD',
  duration text not null default '',
  is_featured boolean not null default false,
  is_published boolean not null default true,
  primary_image_path text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.tour_images (
  id uuid primary key default gen_random_uuid(),
  tour_id uuid not null references public.tours (id) on delete cascade,
  storage_path text not null,
  legacy_url text,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.tour_amenities (
  id uuid primary key default gen_random_uuid(),
  tour_id uuid not null references public.tours (id) on delete cascade,
  name text not null,
  included boolean not null default true,
  sort_order integer not null default 0
);

create table if not exists public.tour_itinerary_items (
  id uuid primary key default gen_random_uuid(),
  tour_id uuid not null references public.tours (id) on delete cascade,
  date_label text not null default '',
  location text not null default '',
  activity text not null default '',
  description text not null default '',
  sort_order integer not null default 0
);

create index if not exists tours_published_featured_idx
  on public.tours (is_published, is_featured);
create index if not exists tour_images_tour_id_idx on public.tour_images (tour_id, sort_order);

-- ---------------------------------------------------------------------------
-- Stays
-- ---------------------------------------------------------------------------
create table if not exists public.stays (
  id uuid primary key default gen_random_uuid(),
  legacy_id integer unique,
  name text not null,
  type text not null default '',
  description text not null default '',
  address text not null default '',
  city text not null default '',
  country text not null default '',
  is_featured boolean not null default false,
  is_published boolean not null default true,
  primary_image_path text,
  currency text not null default 'USD',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.stay_images (
  id uuid primary key default gen_random_uuid(),
  stay_id uuid not null references public.stays (id) on delete cascade,
  storage_path text not null,
  legacy_url text,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.stay_rooms (
  id uuid primary key default gen_random_uuid(),
  stay_id uuid not null references public.stays (id) on delete cascade,
  name text not null,
  price numeric(12, 2) not null default 0,
  capacity integer not null default 0,
  sort_order integer not null default 0
);

create table if not exists public.stay_amenities (
  id uuid primary key default gen_random_uuid(),
  stay_id uuid not null references public.stays (id) on delete cascade,
  name text not null,
  included boolean not null default true,
  sort_order integer not null default 0
);

create index if not exists stays_published_city_idx
  on public.stays (is_published, city);
create index if not exists stay_images_stay_id_idx on public.stay_images (stay_id, sort_order);

-- ---------------------------------------------------------------------------
-- Vehicles
-- ---------------------------------------------------------------------------
create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  legacy_id integer unique,
  make text not null default '',
  model text not null default '',
  year integer not null default 0,
  type text not null default '',
  price_per_day numeric(12, 2) not null default 0,
  currency text not null default 'USD',
  address text not null default '',
  city text not null default '',
  country text not null default '',
  is_featured boolean not null default false,
  is_published boolean not null default true,
  primary_image_path text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.vehicle_images (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  storage_path text not null,
  legacy_url text,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.vehicle_features (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  name text not null,
  included boolean not null default true,
  sort_order integer not null default 0
);

create index if not exists vehicles_published_type_idx
  on public.vehicles (is_published, type);

-- ---------------------------------------------------------------------------
-- Awards / editorial
-- ---------------------------------------------------------------------------
create table if not exists public.awards (
  id uuid primary key default gen_random_uuid(),
  legacy_id integer unique,
  name text not null,
  description text not null default '',
  year integer not null default 0,
  is_published boolean not null default true,
  primary_image_path text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.award_images (
  id uuid primary key default gen_random_uuid(),
  award_id uuid not null references public.awards (id) on delete cascade,
  storage_path text not null,
  legacy_url text,
  sort_order integer not null default 0
);

-- ---------------------------------------------------------------------------
-- Sensitive stubs (Firebase Auth bridge deferred — no anon policies)
-- ---------------------------------------------------------------------------
create table if not exists public.customer_profiles (
  id uuid primary key default gen_random_uuid(),
  firebase_uid text unique,
  legacy_sql_id integer unique,
  full_name text not null default '',
  email text not null default '',
  phone text,
  raw_profile jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.enquiries (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('flight', 'general', 'stay', 'vehicle', 'tour')),
  firebase_uid text,
  legacy_user_id integer,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'received',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  legacy_id text unique,
  firebase_uid text,
  legacy_user_id integer,
  item_type text not null,
  item_legacy_id integer,
  item_id uuid,
  item_name text not null default '',
  num_travelers integer not null default 1,
  total_price numeric(12, 2) not null default 0,
  currency text not null default 'USD',
  payment_status text not null default 'pending',
  start_date date,
  end_date date,
  item_image_json jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

-- updated_at triggers
drop trigger if exists tours_set_updated_at on public.tours;
create trigger tours_set_updated_at before update on public.tours
for each row execute function public.set_updated_at();

drop trigger if exists stays_set_updated_at on public.stays;
create trigger stays_set_updated_at before update on public.stays
for each row execute function public.set_updated_at();

drop trigger if exists vehicles_set_updated_at on public.vehicles;
create trigger vehicles_set_updated_at before update on public.vehicles
for each row execute function public.set_updated_at();

drop trigger if exists awards_set_updated_at on public.awards;
create trigger awards_set_updated_at before update on public.awards
for each row execute function public.set_updated_at();

drop trigger if exists customer_profiles_set_updated_at on public.customer_profiles;
create trigger customer_profiles_set_updated_at before update on public.customer_profiles
for each row execute function public.set_updated_at();

drop trigger if exists enquiries_set_updated_at on public.enquiries;
create trigger enquiries_set_updated_at before update on public.enquiries
for each row execute function public.set_updated_at();

drop trigger if exists bookings_set_updated_at on public.bookings;
create trigger bookings_set_updated_at before update on public.bookings
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.tours enable row level security;
alter table public.tour_images enable row level security;
alter table public.tour_amenities enable row level security;
alter table public.tour_itinerary_items enable row level security;
alter table public.stays enable row level security;
alter table public.stay_images enable row level security;
alter table public.stay_rooms enable row level security;
alter table public.stay_amenities enable row level security;
alter table public.vehicles enable row level security;
alter table public.vehicle_images enable row level security;
alter table public.vehicle_features enable row level security;
alter table public.awards enable row level security;
alter table public.award_images enable row level security;
alter table public.customer_profiles enable row level security;
alter table public.enquiries enable row level security;
alter table public.bookings enable row level security;

-- Public read for published inventory (anon + authenticated).
-- Drop-if-exists so re-applying the migration is safe during M2 rollout.
drop policy if exists tours_public_read on public.tours;
create policy tours_public_read on public.tours
  for select to anon, authenticated
  using (is_published = true);

drop policy if exists tour_images_public_read on public.tour_images;
create policy tour_images_public_read on public.tour_images
  for select to anon, authenticated
  using (exists (
    select 1 from public.tours t where t.id = tour_id and t.is_published = true
  ));

drop policy if exists tour_amenities_public_read on public.tour_amenities;
create policy tour_amenities_public_read on public.tour_amenities
  for select to anon, authenticated
  using (exists (
    select 1 from public.tours t where t.id = tour_id and t.is_published = true
  ));

drop policy if exists tour_itinerary_public_read on public.tour_itinerary_items;
create policy tour_itinerary_public_read on public.tour_itinerary_items
  for select to anon, authenticated
  using (exists (
    select 1 from public.tours t where t.id = tour_id and t.is_published = true
  ));

drop policy if exists stays_public_read on public.stays;
create policy stays_public_read on public.stays
  for select to anon, authenticated
  using (is_published = true);

drop policy if exists stay_images_public_read on public.stay_images;
create policy stay_images_public_read on public.stay_images
  for select to anon, authenticated
  using (exists (
    select 1 from public.stays s where s.id = stay_id and s.is_published = true
  ));

drop policy if exists stay_rooms_public_read on public.stay_rooms;
create policy stay_rooms_public_read on public.stay_rooms
  for select to anon, authenticated
  using (exists (
    select 1 from public.stays s where s.id = stay_id and s.is_published = true
  ));

drop policy if exists stay_amenities_public_read on public.stay_amenities;
create policy stay_amenities_public_read on public.stay_amenities
  for select to anon, authenticated
  using (exists (
    select 1 from public.stays s where s.id = stay_id and s.is_published = true
  ));

drop policy if exists vehicles_public_read on public.vehicles;
create policy vehicles_public_read on public.vehicles
  for select to anon, authenticated
  using (is_published = true);

drop policy if exists vehicle_images_public_read on public.vehicle_images;
create policy vehicle_images_public_read on public.vehicle_images
  for select to anon, authenticated
  using (exists (
    select 1 from public.vehicles v where v.id = vehicle_id and v.is_published = true
  ));

drop policy if exists vehicle_features_public_read on public.vehicle_features;
create policy vehicle_features_public_read on public.vehicle_features
  for select to anon, authenticated
  using (exists (
    select 1 from public.vehicles v where v.id = vehicle_id and v.is_published = true
  ));

drop policy if exists awards_public_read on public.awards;
create policy awards_public_read on public.awards
  for select to anon, authenticated
  using (is_published = true);

drop policy if exists award_images_public_read on public.award_images;
create policy award_images_public_read on public.award_images
  for select to anon, authenticated
  using (exists (
    select 1 from public.awards a where a.id = award_id and a.is_published = true
  ));

-- Sensitive tables: RLS on, zero anon/authenticated policies → deny by default.
-- Service role (migrations / future server) bypasses RLS.
comment on table public.customer_profiles is
  'Firebase Auth bridge deferred; no public RLS policies in M2.';
comment on table public.enquiries is
  'No anon insert/select; write path deferred to secure server bridge.';
comment on table public.bookings is
  'No anon insert/select; legacy bymapara retained for customer booking flows in M2.';
