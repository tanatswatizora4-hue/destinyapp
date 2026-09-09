-- =============================================================================
-- M2 Destiny OS — Dashboard SQL Editor one-paste WITH owned-media seed
-- Project: xchddfpfzrzhlbbmyhyn  (https://xchddfpfzrzhlbbmyhyn.supabase.co)
-- NEVER run against Wanzwei (irgkeksrittimdwwxckl).
--
-- Paste into: Supabase Dashboard → SQL Editor → New query → Run
-- Contains: schema + RLS + storage policies + inventory row upserts (owned paths)
-- After this: still need 81 media objects + inventory/catalog.json in Storage
--             (prefer: DESTINY_SKIP_SCHEMA=1 bash scripts/apply_m2_remote.sh
--              with SUPABASE_ACCESS_TOKEN — or Dashboard Storage uploads)
-- Do NOT use historical inventory_seed.sql (legacy uploads/ paths).
-- =============================================================================


-- >>> BEGIN schema
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

-- >>> BEGIN storage policies
-- Storage policies for public destiny-media bucket (destiny-os only).
-- Idempotent. Does not touch private customer document buckets.
-- Home objects already live; inventory prefixes added for M2.

-- Ensure public marketing bucket exists (no-op if already present).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'destiny-media',
  'destiny-media',
  true,
  52428800,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/json']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Public read for marketing / inventory prefixes only.
drop policy if exists "destiny_media_public_read" on storage.objects;
create policy "destiny_media_public_read"
on storage.objects
for select
to anon, authenticated
using (
  bucket_id = 'destiny-media'
  and (
    name like 'home/%'
    or name like 'tours/%'
    or name like 'stays/%'
    or name like 'vehicles/%'
    or name like 'awards/%'
    or name like 'inventory/%'
    or name like 'branding/%'
    or name like 'placeholders/%'
  )
);

-- No anon/authenticated insert/update/delete policies on destiny-media.
-- Uploads use service_role (bypasses RLS) via migration scripts only.
drop policy if exists "destiny_media_anon_write" on storage.objects;
drop policy if exists "destiny_media_public_write" on storage.objects;

-- >>> BEGIN inventory_seed_owned_media.sql
-- Destiny OS M2 inventory seed with owned media paths where staged
BEGIN;

INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (39, 'PHUKET TOUR', ' STARTING FROM USD1480 PER PERSON
VISAS INCLUDED
FLIGHTS INCLUDED
FOR 04 PAX ON DOUBLE SHARING BASIS

7N THE CHARM RESORT OR SIMILAR
DAILY BREAKFAST
RETURN AIRPORT TRANSFERS
PHI PHI ISLAND TOUR ON SHARING SPEED BOAT (WITHOUT NATIONAL PARK FEE+ LOCAL LUNCH+ PRIVATE TRANSFER
PHUKET CITY TOUR WITH BIG BUDDHA - FOR 06 HOURS
HALF DAY  ELEPHANT SANCTUARY WITH LOCAL LUNCH 
YONA BEACH DAY PASS
01 ENGLISH SPEAKING GUIDE ON ALL TOURS
ALL TOURS AND TRANSFERS ON PRIVATE BASIS
1 SUV USED IN ALL TOURS AND TRANSFERS
', 1480.0, 'USD', '7 NIGHTS 8 DAYS', false, true, 'destiny-media/tours/39/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (38, 'KANGARA RESORT', 'ADULTS USD35
CHILDREN USD25

INCLUDES:
ENTRANCE FEE
QUAD BIKES
HORSE RIDING
BOAT CRUISE

EXCLUSIVE OF :
LUNCH AND TRANSPORT', 35.0, 'USD', 'DAY', false, true, 'destiny-media/tours/38/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (37, 'VISIT FRANCE', 'FLIGHTS INCLUDED
5 NIGHTS ACCOMMODATION IN A 3 STAR HOTEL OR SIMILAR ON A BB BASIS
1 DAY HOP ON HOP BUS TOUR SIC
SEINE RIVER DINNER CRUISE WITH LIVE MUSIC (SPECIAL)
EIFFEL TOWER 2ND LEVEL WITH HOP ON HOP OF STAIRS
1 DAY 2 PARK DISNEYLAND ON SIC (NOT FROM HOTEL)
ARRIVAL AND DEPARTURE TRANSFERS FROM CDG TO PARIS HOTEL ( PRIVATE BASIS0
', 2780.0, 'USD', '5 NIGHTS 6 DAYS', false, true, 'destiny-media/tours/37/primary.png') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (36, 'JAPAN TOUR', 'FLIGHTS 
ACCOMMOSDATIO 3 STAR/ 4 STAR HOTEL OR SIMILAR
DAILY BREAKFAST AND INDIAN/ JAPANESE DINNERS
OSAKA CASTLE SURRONDED BY CHERRY BLOSSOMS
KYOTO''S PHILOSOPHER''S PATH, GION DISTRICT
NIARA DEER PARK & FUSHIMI INARI SHRINE
KENROKU-EN GARDEN - TOP 3 GARDNER''S OF JAPAN
MT FUJI+ ARAKURAYAMA PARK TOAGADA + SAKURA
BULLET TRAIN
PRIVATE TRANSPORTATION
ENGLISH SPEAKING GUIDE
ENTRANCE FEES AS PER ITINERARY
FREE JAPAN  ESIM
ALL TAXES EXCEPT  VISA

RATE', 5600.0, 'USD', '7 NIGHTS 8 DAYS', false, true, 'destiny-media/tours/36/primary.png') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (35, 'IMIRE  GIRLS TRIP', 'USD 95 PER PERSON
INCLUDES:
MORNING AND AFTERNOON TEAS/COFFEES
FULL GAME DRIVE
BUFFET LUNCH IN THE GAME PARK

EXCLUDES:
TRANSPORT

NOTE:
ARRIVAL SHOULD BE BY 10 AM FOR  A FULL GAME DRIVE
DO NOT BRING DRINKS', 95.0, 'USD', 'DAY', false, true, 'destiny-media/tours/35/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (34, 'MORROCO', 'USD 4610 PER PERSON ON A TWIN/ DOUBLE SHARING BASIS
HOTEL
TRANSFERS
SIGHTSEEING

NOTE: PACKAGE RATES ARE SUBJECTED TO FLUCTUATIONS', 4610.0, 'USD', 'N/A', false, true, 'destiny-media/tours/34/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (33, 'KUMBA SHIRI', 'USD40 ADULT
USD25 CHILD

INCLUSVE OF : 
ENTRY TO THE SANCTARY
GUIDED BIRD WALK
BUFFET LUNCH
COMPLIMENTARY DRINK
HOUSEBOAT CRUISE
ACTVITIES 
HORSE RIDING FOR ADULTS', 40.0, 'USD', 'DAY', false, true, 'destiny-media/tours/33/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (32, 'ZAMBEZI ARK CRUISES', 'USD75 INCLUDING PARKING SPCE ', 75.0, 'USD', 'N/A', false, true, 'destiny-media/tours/32/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (31, 'Victoria Falls – Flight of Angels', 'Flight over Victoria Falls; park fees and fuel levy noted

as extra.', 210.0, 'USD', '15-minute scenic flight', false, true, 'destiny-media/tours/31/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (30, 'Zanzibar (Beaches &amp; Island Escapes)', 'Flights from $590', 590.0, 'USD', '5', false, true, 'destiny-media/tours/30/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (29, 'Dubai (Emirates + JW Marriott Marquis)', '1 free night
(Economy/Prem.
Economy) or 2 free
nights (Business/First)

Valid for Harare–Dubai flights with 24hr+ stopover.
Book by 12 Jul 2026; travel 25 Jun–30 Sept 2026.', 0.0, 'USD', 'Stopover offer', false, true, 'destiny-media/tours/29/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (15, 'Israel Holy Land Tour', 'A spiritual journey to the Holy Land. Includes VISA, return flights, all meals, 7 nights accommodation, and all tours and transfers.', 3023.0, 'USD', '8 Days, 7 Nights', true, true, 'destiny-media/tours/15/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (16, 'Zanzibar Trip', 'Includes return flight, airport transfers, 3 nights at Nungwi Beach Resort, daily breakfast, and an island tour.', 1030.0, 'USD', '4 Days, 3 Nights', true, true, 'destiny-media/tours/16/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (17, 'Malawi Trip', 'Includes 3 nights @ Sunbird Hotel, Breakfast, Hotel transfer, Boat cruise, Jet ski, and Return flights.', 1530.0, 'USD', '4 Days, 3 Nights', true, true, 'destiny-media/tours/17/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (18, 'Durban to Mozambique Cruise', '15 - 19 December 2025. Durban >> Pomene >> back to Durban. Includes return flight, 4 days accommodation, and all meals.', 1219.0, 'USD', '5 Days, 4 Nights', true, true, 'destiny-media/tours/18/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (19, 'Explore Singapore', '5 nights 6 days till 31st Sept 2025. Includes return flights, 5 nights accommodation, daily breakfast, Singapore City Tour, Wings Of Time with Cable Car, Madame Tussauds, Marina Bay Sands Sky Park, and all tours/transfers.', 1932.0, 'USD', '6 Days, 5 Nights', true, true, 'destiny-media/tours/19/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (20, 'Archipelago Resort Summer Escape', '3 nights bed and breakfast including return flights. Stay in spacious self-catering casas, dine at our seaside restaurant, dive, island-hop, or unwind.', 1150.0, 'USD', '4 Days, 3 Nights', false, true, 'destiny-media/tours/20/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (21, 'Bali Holiday Package', '6 Days 5 Nights. Includes return air tickets, 6 days and 5 nights at a 4* Hotel, AC transport, driver and tour guide, fast boat Bali - Nussa Penida return, breakfast, lunch and dinner, and entrance ticket.', 1990.0, 'USD', '6 Days, 5 Nights', true, true, 'uploads/IMG-20251025-WA0013.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (22, 'Girls Game Drive Retreat Kariba', 'August 10 to 11. Includes 1 night accommodation @ Spurwing Island, all meals, game drive, national park entry fees. *Excludes transport*.', 190.0, 'USD', '2 Days, 1 Night', false, true, 'destiny-media/tours/22/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (23, 'Musumu River Lodge Binga Tour', '2 nights 3 days (9 - 11 August). Includes breakfast and dinner, half-day guided tour, Tonga Museum, crocodile breeding, natural hot springs, sunset cruise. *Excludes transport*.', 460.0, 'USD', '3 Days, 2 Nights', false, true, 'destiny-media/tours/23/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (24, 'Figtree Camp Selous (Schools)', 'Two nights package. Primary schools $110, Secondary schools $115. Includes full board, 4 activities, 1 educational talk, team building, 1 free t-shirt.', 110.0, 'USD', '3 Days, 2 Nights', false, true, 'uploads/IMG-20251016-WA0002.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (14, 'Kadoma Music Festival 2025', 'Catch Africa''s best, Diamond Platnumz, blasting the stage with Zimbabwe''s own legends Alick Macheso, Winky D, Jah Prayzah, Saintfloew and Gemma Griffiths', 20.0, 'USD', '1 Night', true, true, 'destiny-media/tours/14/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (1, 'Victoria Falls Adventure', 'Experience the thrill of the mighty Victoria Falls. This package includes a guided tour of the falls, a sunset cruise on the Zambezi River, and a visit to a local craft market.', 1250.0, 'USD', '3 Days, 2 Nights', false, true, 'destiny-media/tours/1/primary.jpeg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (2, 'Durban To Mozambique Cruise', '"Embark on an unforgettable coastal odyssey with MSC. Book with us for a 5-day Durban to Mozambique cruise (Dec 15-19) and discover tropical bliss, vibrant cultures, and breathtaking scenery. Unleash your wanderlust!', 1219.0, 'USD', '3 Days, 1 Night', true, true, 'destiny-media/tours/2/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.tours (legacy_id, title, description, price, currency, duration, is_featured, is_published, primary_image_path) VALUES (3, 'Hwange National Park Safari', 'Embark on an unforgettable wildlife safari in Zimbabwe''s largest national park. Search for the Big Five and enjoy the pristine African bush.', 1800.0, 'USD', '4 Days, 3 Nights', false, true, 'destiny-media/tours/3/primary.jpeg') ON CONFLICT (legacy_id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, price=EXCLUDED.price, duration=EXCLUDED.duration, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
DELETE FROM public.tour_images WHERE tour_id IN (SELECT id FROM public.tours WHERE legacy_id IS NOT NULL);
DELETE FROM public.tour_amenities WHERE tour_id IN (SELECT id FROM public.tours WHERE legacy_id IS NOT NULL);
DELETE FROM public.tour_itinerary_items WHERE tour_id IN (SELECT id FROM public.tours WHERE legacy_id IS NOT NULL);
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/39/primary.jpg', 'uploads/6a4f9a97e9470-615724801_1664832577822577_6837233941983207803_n.jpg', 0 FROM public.tours WHERE legacy_id=39;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/38/primary.jpg', 'uploads/6a4f55b845fa5-638097643_1697288214577013_700192901064861172_n.jpg', 0 FROM public.tours WHERE legacy_id=38;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/37/primary.png', 'uploads/6a4f54675bd28-ChatGPT Image Jul 9, 2026, 09_56_32 AM.png', 0 FROM public.tours WHERE legacy_id=37;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/36/primary.png', 'uploads/6a4f5295f1894-ChatGPT Image Jul 9, 2026, 09_49_04 AM.png', 0 FROM public.tours WHERE legacy_id=36;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/35/primary.jpg', 'uploads/6a4e176be2915-655699898_1724774848495016_9085784168804663092_n.jpg', 0 FROM public.tours WHERE legacy_id=35;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/34/primary.jpg', 'uploads/6a4e16b7113b4-659017522_1724776148494886_653600608863616191_n.jpg', 0 FROM public.tours WHERE legacy_id=34;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/33/primary.jpg', 'uploads/6a4e14e4cf46c-657364419_1724779385161229_2149096553167828688_n.jpg', 0 FROM public.tours WHERE legacy_id=33;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/32/primary.jpg', 'uploads/6a4e09e9e45cc-700499814_1768197580819409_6381454881535599423_n.jpg', 0 FROM public.tours WHERE legacy_id=32;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/31/primary.jpg', 'uploads/6a4e08b9d25a3-710739115_1781943649444802_2817451762723528287_n.jpg', 0 FROM public.tours WHERE legacy_id=31;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/30/primary.jpg', 'uploads/6a4e06df711f2-735150058_1811822186456948_101665622254047033_n.jpg', 0 FROM public.tours WHERE legacy_id=30;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/29/primary.jpg', 'uploads/6a4e0663112ef-742045552_1817725842533249_6048909638074682386_n (1).jpg', 0 FROM public.tours WHERE legacy_id=29;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/15/primary.jpg', 'uploads/IMG-20250908-WA0000.jpg', 0 FROM public.tours WHERE legacy_id=15;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'VISA', true, 0 FROM public.tours WHERE legacy_id=15;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Return Flights', true, 1 FROM public.tours WHERE legacy_id=15;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'All Meals', true, 2 FROM public.tours WHERE legacy_id=15;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, '7 Nights Accommodation', true, 3 FROM public.tours WHERE legacy_id=15;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Tours & Transfers', true, 4 FROM public.tours WHERE legacy_id=15;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/16/primary.jpg', 'uploads/IMG-20250902-WA0003.jpg', 0 FROM public.tours WHERE legacy_id=16;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Return Flight', true, 0 FROM public.tours WHERE legacy_id=16;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Airport Transfers', true, 1 FROM public.tours WHERE legacy_id=16;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, '3 Nights @ Nungwi Beach Resort', true, 2 FROM public.tours WHERE legacy_id=16;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Daily Breakfast', true, 3 FROM public.tours WHERE legacy_id=16;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Island Tour', true, 4 FROM public.tours WHERE legacy_id=16;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/17/primary.jpg', 'uploads/IMG-20251016-WA0000.jpg', 0 FROM public.tours WHERE legacy_id=17;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Return Flights', true, 0 FROM public.tours WHERE legacy_id=17;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, '3 Nights @ Sunbird Hotel', true, 1 FROM public.tours WHERE legacy_id=17;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Breakfast', true, 2 FROM public.tours WHERE legacy_id=17;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Hotel Transfer', true, 3 FROM public.tours WHERE legacy_id=17;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Boat Cruise', true, 4 FROM public.tours WHERE legacy_id=17;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Jet Ski', true, 5 FROM public.tours WHERE legacy_id=17;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/18/primary.jpg', 'uploads/IMG-20251004-WA0008.jpg', 0 FROM public.tours WHERE legacy_id=18;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Return Flight', true, 0 FROM public.tours WHERE legacy_id=18;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, '4 Days Accommodation', true, 1 FROM public.tours WHERE legacy_id=18;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'All Meals', true, 2 FROM public.tours WHERE legacy_id=18;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/19/primary.jpg', 'uploads/IMG-20251004-WA0014.jpg', 0 FROM public.tours WHERE legacy_id=19;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Return Flights', true, 0 FROM public.tours WHERE legacy_id=19;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, '5 Nights Accommodation', true, 1 FROM public.tours WHERE legacy_id=19;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Daily Breakfast', true, 2 FROM public.tours WHERE legacy_id=19;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Singapore City Tour', true, 3 FROM public.tours WHERE legacy_id=19;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Wings Of Time', true, 4 FROM public.tours WHERE legacy_id=19;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Cable Car', true, 5 FROM public.tours WHERE legacy_id=19;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Madame Tussauds', true, 6 FROM public.tours WHERE legacy_id=19;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Marina Bay Sands Sky Park', true, 7 FROM public.tours WHERE legacy_id=19;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'All Tours & Transfers', true, 8 FROM public.tours WHERE legacy_id=19;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/20/primary.jpg', 'uploads/IMG-20251024-WA0006.jpg', 0 FROM public.tours WHERE legacy_id=20;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Return Flights', true, 0 FROM public.tours WHERE legacy_id=20;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, '3 Nights Accommodation', true, 1 FROM public.tours WHERE legacy_id=20;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Bed & Breakfast', true, 2 FROM public.tours WHERE legacy_id=20;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'uploads/IMG-20251025-WA0013.jpg', 'uploads/IMG-20251025-WA0013.jpg', 0 FROM public.tours WHERE legacy_id=21;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Return Air Tickets', true, 0 FROM public.tours WHERE legacy_id=21;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, '5 Nights @ 4* Hotel', true, 1 FROM public.tours WHERE legacy_id=21;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'AC Transport', true, 2 FROM public.tours WHERE legacy_id=21;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Driver & Tour Guide', true, 3 FROM public.tours WHERE legacy_id=21;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Fast Boat (Bali - Nussa Penida)', true, 4 FROM public.tours WHERE legacy_id=21;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Breakfast, Lunch & Dinner', true, 5 FROM public.tours WHERE legacy_id=21;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Entrance Ticket', true, 6 FROM public.tours WHERE legacy_id=21;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/22/primary.jpg', 'uploads/IMG-20250902-WA0008.jpg', 0 FROM public.tours WHERE legacy_id=22;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, '1 Night Accommodation', true, 0 FROM public.tours WHERE legacy_id=22;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'All Meals', true, 1 FROM public.tours WHERE legacy_id=22;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Game Drive', true, 2 FROM public.tours WHERE legacy_id=22;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'National Park Entry Fees', true, 3 FROM public.tours WHERE legacy_id=22;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Transport', false, 4 FROM public.tours WHERE legacy_id=22;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/23/primary.jpg', 'uploads/IMG-20250902-WA0009.jpg', 0 FROM public.tours WHERE legacy_id=23;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, '2 Nights Accommodation', true, 0 FROM public.tours WHERE legacy_id=23;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Breakfast & Dinner', true, 1 FROM public.tours WHERE legacy_id=23;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Half-day Guided Tour', true, 2 FROM public.tours WHERE legacy_id=23;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Tonga Museum', true, 3 FROM public.tours WHERE legacy_id=23;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Natural Hot Springs', true, 4 FROM public.tours WHERE legacy_id=23;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Sunset Cruise', true, 5 FROM public.tours WHERE legacy_id=23;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Transport', false, 6 FROM public.tours WHERE legacy_id=23;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'uploads/IMG-20251016-WA0002.jpg', 'uploads/IMG-20251016-WA0002.jpg', 0 FROM public.tours WHERE legacy_id=24;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Full Board', true, 0 FROM public.tours WHERE legacy_id=24;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, '4 Activities', true, 1 FROM public.tours WHERE legacy_id=24;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, '1 Educational Talk', true, 2 FROM public.tours WHERE legacy_id=24;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Team Building', true, 3 FROM public.tours WHERE legacy_id=24;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, '1 Free T-Shirt', true, 4 FROM public.tours WHERE legacy_id=24;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/14/primary.jpg', 'uploads/68e49bd28aec3-kadomamusicfestival.jpg', 0 FROM public.tours WHERE legacy_id=14;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/14/gallery-01.gif', 'uploads/68e49c71927a8-kadoma2.gif', 1 FROM public.tours WHERE legacy_id=14;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/14/gallery-02.jpg', 'uploads/68e49c7192afd-freekadoma.jpg', 2 FROM public.tours WHERE legacy_id=14;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/14/gallery-03.jpg', 'uploads/68e49c7192bc2-busykadom.jpg', 3 FROM public.tours WHERE legacy_id=14;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Transport', true, 0 FROM public.tours WHERE legacy_id=14;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Security', true, 1 FROM public.tours WHERE legacy_id=14;
INSERT INTO public.tour_itinerary_items (tour_id, date_label, location, activity, description, sort_order) SELECT id, '2025-10-11', 'Odyssey, Kadoma', 'Music Festival', 'The biggest music showdown of the year', 0 FROM public.tours WHERE legacy_id=14;
INSERT INTO public.tour_itinerary_items (tour_id, date_label, location, activity, description, sort_order) SELECT id, '2025-10-12', 'Harare', 'Return', '', 1 FROM public.tours WHERE legacy_id=14;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/1/primary.jpeg', 'uploads/68c21f8416dbc-vic1.jpeg', 0 FROM public.tours WHERE legacy_id=1;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/1/gallery-01.jpeg', 'uploads/68c21f8416ea4-vic 2.jpeg', 1 FROM public.tours WHERE legacy_id=1;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/1/gallery-02.jpeg', 'uploads/68c21f8416f15-vic3.jpeg', 2 FROM public.tours WHERE legacy_id=1;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/1/gallery-03.jpeg', 'uploads/68c21f8416f7e-vic 4.jpeg', 3 FROM public.tours WHERE legacy_id=1;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Guided Tour', true, 0 FROM public.tours WHERE legacy_id=1;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Park Fees', true, 1 FROM public.tours WHERE legacy_id=1;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Accommodation', true, 2 FROM public.tours WHERE legacy_id=1;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Lunches', false, 3 FROM public.tours WHERE legacy_id=1;
INSERT INTO public.tour_itinerary_items (tour_id, date_label, location, activity, description, sort_order) SELECT id, '2025-10-10', 'Victoria Falls', 'Arrival & Guided Tour', 'Arrive at Victoria Falls Airport, transfer to hotel. Afternoon guided tour of the thunderous falls.', 0 FROM public.tours WHERE legacy_id=1;
INSERT INTO public.tour_itinerary_items (tour_id, date_label, location, activity, description, sort_order) SELECT id, '2025-10-11', 'Zambezi River', 'Sunset Cruise', 'Morning at leisure. Enjoy a spectacular sunset cruise on the Zambezi River with snacks and drinks.', 1 FROM public.tours WHERE legacy_id=1;
INSERT INTO public.tour_itinerary_items (tour_id, date_label, location, activity, description, sort_order) SELECT id, '2025-10-12', 'Victoria Falls', 'Market Visit & Departure', 'Visit a local craft market for souvenirs before transferring to the airport for departure.', 2 FROM public.tours WHERE legacy_id=1;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/2/primary.jpg', 'uploads/68e4a7c27c9a3-durbanmozambiquecruise.jpg', 0 FROM public.tours WHERE legacy_id=2;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/2/gallery-01.jpg', 'uploads/68e4a7c27cc62-durban2.jpg', 1 FROM public.tours WHERE legacy_id=2;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Expert Guide', true, 0 FROM public.tours WHERE legacy_id=2;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Entrance Fees', true, 1 FROM public.tours WHERE legacy_id=2;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Transport', true, 2 FROM public.tours WHERE legacy_id=2;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Dinner', false, 3 FROM public.tours WHERE legacy_id=2;
INSERT INTO public.tour_itinerary_items (tour_id, date_label, location, activity, description, sort_order) SELECT id, '2025-12-15', 'Durban, South Africa', 'Embark', '', 0 FROM public.tours WHERE legacy_id=2;
INSERT INTO public.tour_itinerary_items (tour_id, date_label, location, activity, description, sort_order) SELECT id, '2025-12-16', 'Indian Ocean', 'Cruising At Sea', '', 1 FROM public.tours WHERE legacy_id=2;
INSERT INTO public.tour_itinerary_items (tour_id, date_label, location, activity, description, sort_order) SELECT id, '2025-12-17', 'Portuguese Island (Inhaca Archipelago), Mozambique', 'Set between the African coast and the Indian Ocean', 'The mild effort involved will be repaid in kiosks serving refreshing beverages and local food. If you like rum, try the Tipo Tinto, which is distilled from local sugar cane.', 2 FROM public.tours WHERE legacy_id=2;
INSERT INTO public.tour_itinerary_items (tour_id, date_label, location, activity, description, sort_order) SELECT id, '2025-12-19', 'Durban, South Africa', 'Disembark', '', 3 FROM public.tours WHERE legacy_id=2;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/3/primary.jpeg', 'uploads/68c21fce2c93b-gone3.jpeg', 0 FROM public.tours WHERE legacy_id=3;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/3/gallery-01.jpeg', 'uploads/68c21fce2ca63-gon2.jpeg', 1 FROM public.tours WHERE legacy_id=3;
INSERT INTO public.tour_images (tour_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/tours/3/gallery-02.jpeg', 'uploads/68c21fce2cafd-gone1.jpeg', 2 FROM public.tours WHERE legacy_id=3;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, '4x4 Game Drives', true, 0 FROM public.tours WHERE legacy_id=3;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'All Meals', true, 1 FROM public.tours WHERE legacy_id=3;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Park Fees', true, 2 FROM public.tours WHERE legacy_id=3;
INSERT INTO public.tour_amenities (tour_id, name, included, sort_order) SELECT id, 'Night Drives', false, 3 FROM public.tours WHERE legacy_id=3;
INSERT INTO public.tour_itinerary_items (tour_id, date_label, location, activity, description, sort_order) SELECT id, '2025-12-01', 'Hwange NP', 'Arrival & Afternoon Drive', 'Fly into Hwange Main Camp and transfer to your safari lodge. Settle in before your first afternoon game drive.', 0 FROM public.tours WHERE legacy_id=3;
INSERT INTO public.tour_itinerary_items (tour_id, date_label, location, activity, description, sort_order) SELECT id, '2025-12-02', 'Hwange NP', 'Full Day Safari', 'Full day of game drives exploring different areas of the park, with a picnic lunch in the bush.', 1 FROM public.tours WHERE legacy_id=3;
INSERT INTO public.tour_itinerary_items (tour_id, date_label, location, activity, description, sort_order) SELECT id, '2025-12-03', 'Hwange NP', 'Walking Safari & Sundowners', 'Experience the bush on foot with a guided walking safari. Enjoy sundowner drinks at a scenic waterhole.', 2 FROM public.tours WHERE legacy_id=3;
INSERT INTO public.tour_itinerary_items (tour_id, date_label, location, activity, description, sort_order) SELECT id, '2025-12-04', 'Hwange NP', 'Final Game Drive & Departure', 'Enjoy one last morning game drive before breakfast and your transfer to the airstrip.', 3 FROM public.tours WHERE legacy_id=3;
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (37, 'FRASER SUITES SUKHUMVIT', 'FRASER SUITES SUKHUMVIT OR SIMILAR', ' STARTING FROM USD 1480 PER PERSON VISA INCLUDED
5 NIGHTS & 6 DAYS

INCLUDES:
DAILY BREAKFAST
RETURN AIRPORT TRANSFERS
SAFARI WORLD & MARINE PARK WITH LOCAL LUNCH
CHAO PHRAYA DINNER CRUISE
BKK CITY TOUR WITH GOLDEN & MARBLE BUDDHA TEMPLES & GERMS GALLERY
SHPPING TOUR FOR 8 HOURS
ONE GUIDE FOR ALL TOURS AND TRANSFERS
THAI INSURANCE
FLIGHTS INCLUDED', 'BANGKOK', 'BANGKOK', 'THAILAND', false, true, 'destiny-media/stays/37/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (36, 'PAMUZINDA SAFARI LODGE', 'LODGE', 'USD278 PER COUPLE
2 NIGHTS
INCLUDES:
BREAKFAST AND DINNER
GAME DRIVE', '', '', 'ZIMBABWE', false, true, 'destiny-media/stays/36/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (35, 'CHENGETA SAFARI', 'LODGE', 'USD 109 PER PERSON PER NIGHT
INCLUSIVE OF BREAKFAST AND DINNER

NOT INCLUSIVE OF :
CANOEING
GAME DRIVE
HORSE RIDING
ELEPHANT INTERACTION', 'Selous, Mashonaland West Province ', '', 'ZIMBABWE', false, true, 'destiny-media/stays/35/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (33, 'MATOBO HILLS LODGE', 'LODGE', 'USD1426 PER COUPLE
RETURN FLIGHTS TO AND FROM HARARE

INCLUSIVE OF :
BREAKFAST
CAR HIRE

ANY TWO ACTIVITIES:
RHINO TRACKING
BUSHMAN CAVE TOUR
RHODE''S GRAVE VISIT OR VILLAGE CULTURAL TOUR
INCLUDES GUIDE
PARK FEES AND REFRESHMENTS', 'MATOBO DISTRICT', 'MATOBO DISTRICT', 'ZIMBABWE', false, true, 'destiny-media/stays/33/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (32, 'ROBINS CAMP', 'CAMP', 'USD115 PER PERSON SHARING PER NIGHT
USD170 PER SINGLE ROOM PER NIGHT
USD60 PER CHILD (6-12) PER NIGHT
(0-5 YEARS) FREE

FLIGHTS USD460 PERSON
VIC FALLS AIRPOT/VIC FALLS TOWN TO ROBINS CAMP
USD120 PER PERSON ONE WAY
ROBINS CAMP TO VIC FALLS AIRPORT/ VIC FALLS TOWN
USD 120 PER PERSON ONE WAY
', 'HWANGE', 'HWANGE DISTRICT', 'ZIMBABWE', false, true, 'destiny-media/stays/32/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (31, 'ZENOBIA BEACH RESORT ', 'RESORT', 'USD 1941 PER COUPLE
3 NIGHTS
INCLUSIVE OF :

QUEEN ROOM WITH SEA VIEW
RETURN FLIGHTS
PATIO
MINIBAR
HIGH FLOOR FOR GOOD SEA VIEW
BREAKFAST 10% OFF FOOD / DRINK', 'NUNGWI', 'NUNGWI', 'TANZANIA', false, true, 'destiny-media/stays/31/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (30, 'SMILE BOUTIQUE BEACH HOTEL NUNGWI', 'HOTEL', 'USD2042
2 ADULTS
4 NIGHTS

INCLUSIVE OF :
RETURN FLIGHTS
ACCOMMODATION
CONTINENTAL BREAKFAST
SEA VIEW
BALCONY PRIVATE BATHROOM
COURTYARD', 'NUNGWI', 'NUNGWI', 'TANZANIA', false, true, 'destiny-media/stays/30/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (29, 'SHASHANI LODGE', 'LODGE', '2 NIGHTS 3 DAYS
USD352

INCLUSIVE OF :
ACCOMMODATION
DINNER, BREAKFASTAND LUNCH
NIGHT GAME DRIVE
GUIDED WALK
FREE FISHING( BRING OWN BAIT AND TACKLE)', 'MATOBO NATIONAL PARK', 'MATOBO DISTRICT', 'ZIMBABWE', false, true, 'destiny-media/stays/29/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (28, 'MASUMU RIVER LODGE', 'LODGE', 'QUICK GETAWAY
USD680
2 NIGHTS 3 DAYS
2 ADULTS

INCLUSIVE OF 
LUXURY BEDROOM
FULL BOARD BASIS9 BREAKFAST, LUNCH AND DINNER)
HALF DAY BINGA GUIDED TOUR OF MUSEUM
CROCODILE FEEDING SANCTUARY
NATURAL HOT SPRINGS + LOCAL SCHOOL
SUNSET CRUISE
CULTURAL TOUR', 'BINGA', 'BINGA', 'ZIMBABWE', false, true, 'destiny-media/stays/28/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (27, 'HIDDEN VALLEY BINDURA', 'LODGE', 'USD 240
TWO ADULTS SHARING
SELF CATERING
2 NIGHTS AND 3 DAYS
BOATCRUISE
SPEED BOAT RIDE
TARGET SHOTING (ARCHERY)', 'BINDURA', 'BINDURA', 'ZIMBABWE', false, true, 'destiny-media/stays/27/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (26, 'EGYPT TOUR', 'HOTEL', ' 4 NIGHTS 5 DAYS
USD 2169 PER PERSON 
SHARING BASIS
FLIGHTS INCLUDED
PACKAGE INCLUDES:
HOTEL
TRANSFERS
SIGHT SEEING
MEALS

NOTE:
ALL ROOMS, RATES AND SERVICES ARE SUBJECT TO FLUCTUATIONS AND AVAILABILITY AT THE TIME OF CONFIRMATION

', 'EGYPT', '', 'EGYPT', false, true, 'destiny-media/stays/26/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (25, 'KENYA', 'HOTEL', '4 NIGHTS 5 DAYS
USD1800 PER PERSON
PACKAGE INCLUDES:
RETURN FLIGHTS
ACCOMMODATION
BREAKFAST AND DINNER

NOTE:

RATES ARE SUBJECT TO FLUCTUATION', 'MALINDI', 'MALINDI', 'KENYA', false, true, 'destiny-media/stays/25/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (24, 'CUTTY SARK LODGE', 'LODGE', '2 NIGHTS 3 DAYS 
USD 750 
6 ADULTS VILLA 
3 BEDROOM APARTMENT

2 NIGHTS 3 DAYS 
USD 250 PER COUPLE
2 PERSON APARTMENT BED ONLY


INCLUSIVE OF:ACCOMMODATION
PRIVATE KITCHEN
TOILETRIES
SELF CATERING', '1 Nzou Drive, Kariba', 'KARIBA', 'ZIMBABWE', false, true, 'destiny-media/stays/24/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (23, 'TSWA SAFARI ISLAND', 'LODGE', '3 NIGHTS 4 DAYS
USD3200PER PERSON SHARING
PACKAGE INCLUDES:
RETURN FLIGHTS (HARARE- VICTORIA FALLS)
4X4 TRANSFERS IN AN OPEN GAME VIEWER VEHICLE
BOAT TRANSFER TO THE ISLAND 
ACCOMMODATION
GUIDED ISLAND WALKS
FISHING
ALL MEALS
BASIC LAUNDRY
ZAMBEZI NATIONALPAR- TSOWA ENTRANCE
ONE NIGHT ZAMBEZI NATIONAL PARK FEE
ONE DAY RAINFOREST FEE 
CHOOSE 2 ADDITIONALACTIVITIESPER DAY


NOTE:
ACTIVITIES ARE WEATHER DEPENDENT AND SUBJECT TO AVAILABILITY 
NO CHILDREN UNDER TWO YEARS

VALIDITY: 1ST OCT 2026 TO 10 JAN 2027', 'TSOWA SAFARI', 'ZAMBEZI NATIONA PARK', 'ZIMBABWE', false, true, 'destiny-media/stays/23/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (22, 'LAGOON BEACH', 'HOTEL', '4 NIGHTS/ 5 DAYS
USD 2885 2 ADULTS/ SHARING
INCLUDES:
RETURN FLIGHTS
AIRPORT TRANSFERS
ACCOMMODATION
BREAKFAST
HOP ON HOP OFF CITY TOUR WITH OPTIONAL CRUISE
1 HOUR COASTAL CRUISE FROM CAPETOWN
HALF DAY TABLE MOUNTAIN CABLE CAR TICKETS
THE ART OF MAKING CHOCOLATE

NOTE: SUBJECT TO FLUCTUATIONS', '1 Lagoon Gate Drive Cape Town 7441', 'CAPE TOWN', 'SOUTH AFRICA', false, true, 'destiny-media/stays/22/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (21, 'VICTORIA FALLS SAFARI LODGE', 'LODGE', '3 NIGHTS 4 DAYS 
USD790 PER PERSON
SHARING

INCLUDES:
RETURN AIRPOT TRANSFERS MIN 2 PAX
2DINNERS (MaKuwa- Kuwa Restaurant for lodge/ 1 dinner at the Boma- dinner & drummer show ( with return shuttle)
2 Vultue culture experience lunches
luxury deck sunset cruise on the Zambezi Explorer
30 minutes Music Ease massage at the Victoria Falls Safari Spa
complimentary  shuttle to the Rainforest & town 
complimentary wifi

NOTE :
NEW BOOKINGS ONLY
SUBJECTTO AVAIABILITY AND FLUCTUATION OF RATES', 'VICTORIA FALLS', 'VICTORIA FALLS', 'Zimbabwe', false, true, 'destiny-media/stays/21/primary.png', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (20, 'VICTORIA FALLS SAFARI LODGE', 'LODGE', '3 NIGHTS 4 DAYS 
USD790 PER PERSON
SHARING

INCLUDES:
RETURN AIRPOT TRANSFERS MIN 2 PAX
2DINNERS (MaKuwa- Kuwa Restaurant for lodge/ 1 dinner at the Boma- dinner & drummer show ( with return shuttle)
2 Vultue culture experience lunches
luxury deck sunset cruise on the Zambezi Explorer
30 minutes Music Ease massage at the Victoria Falls Safari Spa
complimentary  shuttle to the Rainforest & town 
complimentary wifi

NOTE :
NEW BOOKINGS ONLY
SUBJECTTO AVAIABILITY AND FLUCTUATION OF RATES', 'VICTORIA FALLS', 'VICTORIA FALLS', '', false, true, 'destiny-media/stays/20/primary.png', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (19, 'CHIVERO LAKE CHALET', 'CHALET', 'FAMILY PACKAGE 
2 NIGHTS/ 3 DAYS
USD550 PER CHALET UP TO 4 GUESTS

INCLUDES:
2 NIGHTS IN A LAKESIDE CHALET
ALL MEALS INCLUDED
FREE KUIMBA SHIRI SANCTUARY ENTRY
HORSE RIDING EXPERIENCE
HOUSEBOAT CRUISE ON LAKE CHIVERO
GUIDED BIRD WALK THROUGH THE SANCTUARY

NOTE:
ONLY 4 CHALETS AVAILABLE
MAXIMUM 6 GUESTS PER CHALET

PACKAGE 1 :FRIDAY NIGHT TO SATURDAY NIGHT
PACKAGE 2 : SUNDAY NIGHT TO MONDAY NIGHT', 'KUIMBA SHIRI', 'ZVIMBA', 'ZIMBABWE', false, true, 'destiny-media/stays/19/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (18, 'THE EDWARD', 'HOTEL', 'USD 2470 
2 ADULTS
3 NIGHTS/ 4 DAYS

PACKAGE INCLUDES:
RETURN FLIGHTS
ACCOMMODATION
BREAKFAST
HALF DAY CITY TOUR
', '149 Marine Parade Durban 4001', 'DURBAN', 'SOUTH AFRICA', false, true, 'destiny-media/stays/18/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (17, 'CHAMABONDO', 'CAMP', 'ZAMBEZI NATIOANL PARK 
USD3065
 2 ADULTS 
3 NIGHTS/4 DAYS

PACKAGE INCLUDES:
RETURN FLIGHTS
TRANSFERS FROM VIC FALLS AIRPORT
TRAVEL INSURANCE
ACCOMMODATION
ALL MEALS
2 ACTIVITIES PER DAY
GAME DRIVE / NIGHT DRIVE
LAUNDRY', 'ZAMBEZI NATIONAL PARK', 'HWANGE DISTRICT', 'ZIMBABWE', false, true, 'destiny-media/stays/17/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (16, 'NYAMAKWERE LODGE', 'LODGE', 'USD215
2 NIGHTS/ 3 DAYS

INCLUSIVE OF :
ACCOMMODATION
BREAKFAST', 'MUTOKO', 'MUTOKO', 'ZIMBABWE', false, true, 'destiny-media/stays/16/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (15, 'NKANDLA RESORTS', 'RESORT', 'USD350 PER PERSON/ PER NIGHT
1 NIGHT/2 DAYS

INCLUSIE OF :
ACCOMMDATION 
BREAKFAST', '197 CIRCULAR DRIVE', 'BULAWAYO', 'ZIMBABWE', false, true, NULL, 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (14, 'SKY DECK MOUTAIN REREAT', 'LODGE', '3 NIGHTS / 4 DAYS
USD6800
4 GUEST
DOUBLE/ TWIN ROOM

INCLUSIVE OF :
ACCOMMODATION
FU ENGLISH & CONTINENTL INNER
LUNCH
AFTERNOON SNACKS
THREE COURSE DINNER

EXCLUSIVE OF :
LAUNDRY SERVICE
ACTIVITIES
BEVERAGES

NOTE;
TRANSPORT TO THE PROPERTY AVAILABLE ON REQUEST 
', 'NYANGA', 'NYANGA', 'ZIMBABWE', false, true, 'destiny-media/stays/14/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (13, 'DAISY GUEST HOUSE', 'TIGER GOLD NIGHT ( GUEST HOUSE)', 'USD350 PER NIGHT
9 PASSENGERS
4 CABINS
ON BOARD CAPTAIN
ON BOARD CHEF', 'KARIBA', 'KARIBA', 'Zimbabwe', false, true, 'destiny-media/stays/13/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (12, 'DAISY GUEST HOUSE', 'NYATHI HOUSE BOAT', 'USD550 PER NIGHT
11 PAX 4 CABINS
JACUZZI
INTERIOR AND EXTERIOR DINING AREA
ON BOARD CAPTAIN 
ON BOARD CHEF', 'KARIBA', 'KARIBA', 'Zimbabwe', false, true, 'destiny-media/stays/12/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (11, 'CASTELO BEACH RESORT', 'RESORT', 'USD 3560 (2 GUESTS)
5 NIGHTS/6 DAYS
RETURN FLIGHTS ( HARARE-MAPUTO)
ACCOMMODATION ( DELUXE SUITE)
ALL MEALS', 'Linga Linga, Morrumbene 1308', 'MAPUTO', 'MOZAMBIQUE', false, true, 'destiny-media/stays/11/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (10, 'GREAT ZIMBABWE HOTEL', 'HOTEL', 'WEEKEND GETAWAY
GUIDED TOR OF MONUMENTS 
BREAKFAST
LUNCH 
DINNER

OPTIONAL ACTIVITIES:
TOUR OF THE CITY ( UZENDA VILLAGE0
CURIO MARKETS
SUNSET VIEWING
LAKE MUTIRIKWI SCENIC TOURS

NOTE: SELF DRIVE!!

2 NIGHTS/ 3 DAYS- USD296 PER COUPLE
1 NIGHT/ 2 DAYS- USD198 PER COUPLE ', 'GREAT ZIMBABWE HOTEL', 'MASVINGO', 'Zimbabwe', false, true, 'destiny-media/stays/10/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (9, 'VICTORIA FALLS OASIS HOTEL', 'HOTEL', 'USD925 PER PERSON
RETURN FLIGHT 
AIRPORT TRANSFERS
ACCOMMODATION 
ENGLISH/CONTINENTAL BREAKFAST 
DINNER CRUISE 
PARK FEE
1ST NOV TO 20TH DEC 2026 ', 'VICTORIA FALLS ', 'VICTORIA FALLS', 'Zimbabwe', false, true, 'destiny-media/stays/9/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (8, 'KASAMBABEZI LODGE', 'LODGE', '2 NIGHTS 3 DAYS
USD870 2 ADULTS 2 KIDS
FLIGHT OPTIONS AVAILABE ON REQUEST 
BREAKFAST
', 'VICTORIA FALLS ', 'VICTORIA FALLS', 'Zimbabwe', false, true, 'destiny-media/stays/8/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (7, 'Samanzi Lodge, Victoria Falls', 'LODGE', '2 nights / 3 days USD1480 per person

sharing

Return flights (HRE–VFA), airport transfers,
accommodation, all meals, local beers/soft
drinks/house wines, complimentary 30-min massage,
lounge access.', 'VICTORIA FALLS ', 'VICTORIA FALLS', 'Zimbabwe', false, true, 'destiny-media/stays/7/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (6, 'Victoria Falls Rainbow Hotel', 'HOTEL', 'Tour of the Falls, Bridge Tour, Boma Dinner, Game
Drive, Bungee Jumping. Flight options available on
request.

4 nights / 5 days

USD1120 per person

sharing', 'Escapes)  - Flights from $590 General destination promo flyer.  3 Victoria Falls Rainbow Hotel', 'VICTORIA FALLS', 'Zimbabwe', false, true, 'destiny-media/stays/6/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (4, 'Troutbeck Resort Nyanga', 'Resort', 'Discover serene landscapes, tranquil lakes, and warm hospitality. $240 per night double room (2 adults) - Bed & breakfast. Alot of activities for an extra charge.', '', 'Nyanga', 'Zimbabwe', false, true, 'destiny-media/stays/4/primary.jpeg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (5, 'Musumu River Lodge', 'Lodge', 'Escape to Paradise! Discover Musumu River Lodges Binga! Breathtaking Views. Stunning Sunsets, Amazing wildlife, Luxurious Accommodation.', '', 'Binga', 'Zimbabwe', true, true, 'destiny-media/stays/5/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (1, 'Kariba Safari Lodges', 'City Lodge', 'Lake views, lush greenery, and warm hospitality. Kariba Safari Lodge awaits! book with us today', 'Mica Dr', 'Kariba', 'Zimbabwe', true, true, 'destiny-media/stays/1/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (2, 'Musumu River Lodge', 'Safari Lodge', 'Escape to Paradise! Discover Musumu River Lodges Binga! Breathtaking Views. Stunning Sunsets, Amazing wildlife, Luxurious Accommodation. All at the Heart of Binga!
Contact us now on reservations@destinytravelzim.com  or call +263242308326/346 or whatsap +263772375941', '', 'Binga', 'Zimbabwe', true, true, 'destiny-media/stays/2/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.stays (legacy_id, name, type, description, address, city, country, is_featured, is_published, primary_image_path, currency) VALUES (3, 'Sable Sands Safari Camp', 'Tented Camp', 'An authentic tented camp experience in a private concession bordering Hwange National Park.', 'Hwange Private Concession', 'Hwange', 'Zimbabwe', true, true, 'destiny-media/stays/3/primary.jpg', 'USD') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, type=EXCLUDED.type, description=EXCLUDED.description, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
DELETE FROM public.stay_images WHERE stay_id IN (SELECT id FROM public.stays WHERE legacy_id IS NOT NULL);
DELETE FROM public.stay_rooms WHERE stay_id IN (SELECT id FROM public.stays WHERE legacy_id IS NOT NULL);
DELETE FROM public.stay_amenities WHERE stay_id IN (SELECT id FROM public.stays WHERE legacy_id IS NOT NULL);
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/37/primary.jpg', 'uploads/6a54c1b399064-616835563_1664833494489152_6348076497884262295_n.jpg', 0 FROM public.stays WHERE legacy_id=37;
INSERT INTO public.stay_rooms (stay_id, name, price, capacity, sort_order) SELECT id, 'FRASER SUITS', 0, 0, 0 FROM public.stays WHERE legacy_id=37;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/36/primary.jpg', 'uploads/6a4f9dd72fab2-615471192_1663083854664116_2649064526261562484_n.jpg', 0 FROM public.stays WHERE legacy_id=36;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/35/primary.jpg', 'uploads/6a4f9b8069725-615434009_1663086194663882_123611080104403035_n.jpg', 0 FROM public.stays WHERE legacy_id=35;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/33/primary.jpg', 'uploads/6a4f5b6c2af0b-616827839_1669620824010419_5039646770684918639_n.jpg', 0 FROM public.stays WHERE legacy_id=33;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/32/primary.jpg', 'uploads/6a4f5a8df12bd-626999792_1681118199527348_8781928959766861665_n.jpg', 0 FROM public.stays WHERE legacy_id=32;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/31/primary.jpg', 'uploads/6a4f593b357f3-627143344_1682877346018100_4256269271618478209_n.jpg', 0 FROM public.stays WHERE legacy_id=31;
INSERT INTO public.stay_rooms (stay_id, name, price, capacity, sort_order) SELECT id, 'QUEEN ROOM', 0, 2, 0 FROM public.stays WHERE legacy_id=31;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/30/primary.jpg', 'uploads/6a4f5851324d7-626158837_1682879592684542_3549665868704782837_n.jpg', 0 FROM public.stays WHERE legacy_id=30;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/29/primary.jpg', 'uploads/6a4f57861b988-639991094_1696240514681783_1183523098736264155_n.jpg', 0 FROM public.stays WHERE legacy_id=29;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/28/primary.jpg', 'uploads/6a4f56c33b8ef-639229923_1696241041348397_4416506335286417851_n.jpg', 0 FROM public.stays WHERE legacy_id=28;
INSERT INTO public.stay_rooms (stay_id, name, price, capacity, sort_order) SELECT id, 'LUXURY ROOM', 0, 2, 0 FROM public.stays WHERE legacy_id=28;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/27/primary.jpg', 'uploads/6a4f553251c63-641399392_1699904650982036_9069118774992262354_n.jpg', 0 FROM public.stays WHERE legacy_id=27;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/26/primary.jpg', 'uploads/6a4e48ed3217b-651035371_1713846052921229_6431422086256641855_n.jpg', 0 FROM public.stays WHERE legacy_id=26;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/25/primary.jpg', 'uploads/6a4e451d4395a-653050733_1716642312641603_1757143874607527524_n.jpg', 0 FROM public.stays WHERE legacy_id=25;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/24/primary.jpg', 'uploads/6a4e444e2acef-651751033_1717060289266472_8582386724155725165_n.jpg', 0 FROM public.stays WHERE legacy_id=24;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/23/primary.jpg', 'uploads/6a4e4379acf58-653704075_1719141525725015_9167148484667333969_n.jpg', 0 FROM public.stays WHERE legacy_id=23;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/22/primary.jpg', 'uploads/6a4e415833cf9-656647058_1722145902091244_4829004906901322191_n.jpg', 0 FROM public.stays WHERE legacy_id=22;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/21/primary.png', 'uploads/6a4e3f81708b8-ChatGPT Image Jul 8, 2026, 02_08_19 PM.png', 0 FROM public.stays WHERE legacy_id=21;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/20/primary.png', 'uploads/6a4e3f7c569dc-ChatGPT Image Jul 8, 2026, 02_08_19 PM.png', 0 FROM public.stays WHERE legacy_id=20;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/19/primary.jpg', 'uploads/6a4e1bd3db9a2-657163835_1722491342056700_4321707265649208640_n.jpg', 0 FROM public.stays WHERE legacy_id=19;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/18/primary.jpg', 'uploads/6a4e194647330-656312260_1724773688495132_1174615719230396529_n.jpg', 0 FROM public.stays WHERE legacy_id=18;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/17/primary.jpg', 'uploads/6a4e142b7d0bc-657331897_1727557841550050_7331887577038956413_n.jpg', 0 FROM public.stays WHERE legacy_id=17;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/16/primary.jpg', 'uploads/6a4e1337034cf-675020679_1746704992968668_8195398866841603539_n.jpg', 0 FROM public.stays WHERE legacy_id=16;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/14/primary.jpg', 'uploads/6a4e12308366a-678655289_1747526919553142_1804452063333086943_n.jpg', 0 FROM public.stays WHERE legacy_id=14;
INSERT INTO public.stay_rooms (stay_id, name, price, capacity, sort_order) SELECT id, 'DOUBLE ROOM', 6800.0, 0, 0 FROM public.stays WHERE legacy_id=14;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/13/primary.jpg', 'uploads/6a4e0ddb08cad-677055824_1747531492886018_465792238771702595_n.jpg', 0 FROM public.stays WHERE legacy_id=13;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/12/primary.jpg', 'uploads/6a4e0d8aeab65-679081833_1747531572886010_8241190597285094904_n.jpg', 0 FROM public.stays WHERE legacy_id=12;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/11/primary.jpg', 'uploads/6a4e0c9750e3d-677063597_1748458519459982_4606751693495945160_n.jpg', 0 FROM public.stays WHERE legacy_id=11;
INSERT INTO public.stay_rooms (stay_id, name, price, capacity, sort_order) SELECT id, 'DELUXE SUITE', 0, 0, 0 FROM public.stays WHERE legacy_id=11;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/10/primary.jpg', 'uploads/6a4e0baa55e73-684908563_1754812892157878_7537154398826253792_n.jpg', 0 FROM public.stays WHERE legacy_id=10;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/9/primary.jpg', 'uploads/6a4e0ac5230f9-690178754_1762327108073123_5929880093508995947_n.jpg', 0 FROM public.stays WHERE legacy_id=9;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/8/primary.jpg', 'uploads/6a4e0973085fc-701757966_1771935113778989_4758451502969602632_n.jpg', 0 FROM public.stays WHERE legacy_id=8;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/7/primary.jpg', 'uploads/6a4e08459ab54-714989930_1786588908980276_8190643222706287963_n.jpg', 0 FROM public.stays WHERE legacy_id=7;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/6/primary.jpg', 'uploads/6a4e07a5c61d1-729186459_1806601646979002_8901278662318032669_n.jpg', 0 FROM public.stays WHERE legacy_id=6;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/4/primary.jpeg', 'uploads/69fc507b55985-e96a075e-bb9a-4d72-a1a4-6ea8ec26b059.jpeg', 0 FROM public.stays WHERE legacy_id=4;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/4/gallery-01.jpeg', 'uploads/69fdb8cd0328a-e96a075e-bb9a-4d72-a1a4-6ea8ec26b059.jpeg', 1 FROM public.stays WHERE legacy_id=4;
INSERT INTO public.stay_rooms (stay_id, name, price, capacity, sort_order) SELECT id, 'Double Room', 240.0, 2, 0 FROM public.stays WHERE legacy_id=4;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'Bed & Breakfast', true, 0 FROM public.stays WHERE legacy_id=4;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'Horse Riding', false, 1 FROM public.stays WHERE legacy_id=4;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'Golf', false, 2 FROM public.stays WHERE legacy_id=4;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'Lake Activities', false, 3 FROM public.stays WHERE legacy_id=4;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/5/primary.jpg', 'uploads/IMG-20250902-WA0009.jpg', 0 FROM public.stays WHERE legacy_id=5;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'Stunning Views', true, 0 FROM public.stays WHERE legacy_id=5;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'Luxurious Accommodation', true, 1 FROM public.stays WHERE legacy_id=5;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'Swimming Pool', true, 2 FROM public.stays WHERE legacy_id=5;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/1/primary.jpg', 'uploads/68e49df503656-karibasafarilodges.jpg', 0 FROM public.stays WHERE legacy_id=1;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/1/gallery-01.jpg', 'uploads/68e49df50379e-kariba2.jpg', 1 FROM public.stays WHERE legacy_id=1;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/1/gallery-02.jpg', 'uploads/68e49df5038d3-kariba3.jpg', 2 FROM public.stays WHERE legacy_id=1;
INSERT INTO public.stay_rooms (stay_id, name, price, capacity, sort_order) SELECT id, 'Standard Queen Room', 150.0, 2, 0 FROM public.stays WHERE legacy_id=1;
INSERT INTO public.stay_rooms (stay_id, name, price, capacity, sort_order) SELECT id, 'Executive Suite', 250.0, 2, 1 FROM public.stays WHERE legacy_id=1;
INSERT INTO public.stay_rooms (stay_id, name, price, capacity, sort_order) SELECT id, 'Family Room', 220.0, 4, 2 FROM public.stays WHERE legacy_id=1;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'WiFi', true, 0 FROM public.stays WHERE legacy_id=1;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'Swimming Pool', true, 1 FROM public.stays WHERE legacy_id=1;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'Airport Shuttle', false, 2 FROM public.stays WHERE legacy_id=1;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'Gym', true, 3 FROM public.stays WHERE legacy_id=1;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/2/primary.jpg', 'uploads/68e49f8880332-musumuriverlodgebinga.jpg', 0 FROM public.stays WHERE legacy_id=2;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/2/gallery-01.jpg', 'uploads/68e49f88805e8-musumu1.jpg', 1 FROM public.stays WHERE legacy_id=2;
INSERT INTO public.stay_rooms (stay_id, name, price, capacity, sort_order) SELECT id, 'River-Facing Double', 300.0, 2, 0 FROM public.stays WHERE legacy_id=2;
INSERT INTO public.stay_rooms (stay_id, name, price, capacity, sort_order) SELECT id, 'Luxury Tent', 450.0, 2, 1 FROM public.stays WHERE legacy_id=2;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'Private Balcony', true, 0 FROM public.stays WHERE legacy_id=2;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'Air Conditioning', true, 1 FROM public.stays WHERE legacy_id=2;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'Restaurant', true, 2 FROM public.stays WHERE legacy_id=2;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'Guided Tours', false, 3 FROM public.stays WHERE legacy_id=2;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/3/primary.jpg', 'uploads/68c222ad3cd52-sable1.jpg', 0 FROM public.stays WHERE legacy_id=3;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/3/gallery-01.jpg', 'uploads/68c222ad3d0a0-sa2.jpg', 1 FROM public.stays WHERE legacy_id=3;
INSERT INTO public.stay_images (stay_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/stays/3/gallery-02.jpg', 'uploads/68c222ad3d18b-sa3.jpg', 2 FROM public.stays WHERE legacy_id=3;
INSERT INTO public.stay_rooms (stay_id, name, price, capacity, sort_order) SELECT id, 'Luxury Safari Tent', 550.0, 2, 0 FROM public.stays WHERE legacy_id=3;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'En-suite Bathroom', true, 0 FROM public.stays WHERE legacy_id=3;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'All-inclusive', true, 1 FROM public.stays WHERE legacy_id=3;
INSERT INTO public.stay_amenities (stay_id, name, included, sort_order) SELECT id, 'Guided Game Drives', true, 2 FROM public.stays WHERE legacy_id=3;
INSERT INTO public.vehicles (legacy_id, make, model, year, type, price_per_day, currency, address, city, country, is_featured, is_published, primary_image_path) VALUES (1, 'Toyota', 'Hilux 4x4', 2023, 'Truck', 120.0, 'USD', '55 Harare Drive', 'Harare', 'Zimbabwe', true, true, 'destiny-media/vehicles/1/primary.webp') ON CONFLICT (legacy_id) DO UPDATE SET make=EXCLUDED.make, model=EXCLUDED.model, year=EXCLUDED.year, type=EXCLUDED.type, price_per_day=EXCLUDED.price_per_day, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.vehicles (legacy_id, make, model, year, type, price_per_day, currency, address, city, country, is_featured, is_published, primary_image_path) VALUES (2, 'Toyota', 'Corolla', 2022, 'Sedan', 60.0, 'USD', '55 Harare Drive', 'Harare', 'Zimbabwe', true, true, 'destiny-media/vehicles/2/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET make=EXCLUDED.make, model=EXCLUDED.model, year=EXCLUDED.year, type=EXCLUDED.type, price_per_day=EXCLUDED.price_per_day, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.vehicles (legacy_id, make, model, year, type, price_per_day, currency, address, city, country, is_featured, is_published, primary_image_path) VALUES (3, 'Mercedes-Benz', 'Sprinter', 2021, 'Shuttle', 150.0, 'USD', '12 Airport Road', 'Harare', 'Zimbabwe', true, true, 'destiny-media/vehicles/3/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET make=EXCLUDED.make, model=EXCLUDED.model, year=EXCLUDED.year, type=EXCLUDED.type, price_per_day=EXCLUDED.price_per_day, address=EXCLUDED.address, city=EXCLUDED.city, country=EXCLUDED.country, is_featured=EXCLUDED.is_featured, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
DELETE FROM public.vehicle_images WHERE vehicle_id IN (SELECT id FROM public.vehicles WHERE legacy_id IS NOT NULL);
DELETE FROM public.vehicle_features WHERE vehicle_id IN (SELECT id FROM public.vehicles WHERE legacy_id IS NOT NULL);
INSERT INTO public.vehicle_images (vehicle_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/vehicles/1/primary.webp', 'uploads/68c222df5c074-d41.webp', 0 FROM public.vehicles WHERE legacy_id=1;
INSERT INTO public.vehicle_images (vehicle_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/vehicles/1/gallery-01.webp', 'uploads/68c222df5c3ab-d42.webp', 1 FROM public.vehicles WHERE legacy_id=1;
INSERT INTO public.vehicle_features (vehicle_id, name, included, sort_order) SELECT id, 'Air Conditioning', true, 0 FROM public.vehicles WHERE legacy_id=1;
INSERT INTO public.vehicle_features (vehicle_id, name, included, sort_order) SELECT id, 'GPS', false, 1 FROM public.vehicles WHERE legacy_id=1;
INSERT INTO public.vehicle_features (vehicle_id, name, included, sort_order) SELECT id, 'Rooftop Tent', false, 2 FROM public.vehicles WHERE legacy_id=1;
INSERT INTO public.vehicle_images (vehicle_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/vehicles/2/primary.jpg', 'uploads/68c2237c7a4da-co1.avif', 0 FROM public.vehicles WHERE legacy_id=2;
INSERT INTO public.vehicle_features (vehicle_id, name, included, sort_order) SELECT id, 'Air Conditioning', true, 0 FROM public.vehicles WHERE legacy_id=2;
INSERT INTO public.vehicle_features (vehicle_id, name, included, sort_order) SELECT id, 'Bluetooth Audio', true, 1 FROM public.vehicles WHERE legacy_id=2;
INSERT INTO public.vehicle_images (vehicle_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/vehicles/3/primary.jpg', 'uploads/68c223a6319a8-sprint1.avif', 0 FROM public.vehicles WHERE legacy_id=3;
INSERT INTO public.vehicle_images (vehicle_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/vehicles/3/gallery-01.jpeg', 'uploads/68c223a631ac7-sprint2.jpeg', 1 FROM public.vehicles WHERE legacy_id=3;
INSERT INTO public.vehicle_features (vehicle_id, name, included, sort_order) SELECT id, 'Air Conditioning', true, 0 FROM public.vehicles WHERE legacy_id=3;
INSERT INTO public.vehicle_features (vehicle_id, name, included, sort_order) SELECT id, '12 Seater', true, 1 FROM public.vehicles WHERE legacy_id=3;
INSERT INTO public.vehicle_features (vehicle_id, name, included, sort_order) SELECT id, 'Driver available', false, 2 FROM public.vehicles WHERE legacy_id=3;
INSERT INTO public.awards (legacy_id, name, description, year, is_published, primary_image_path) VALUES (4, 'Best Customer Service - Gold Winner', 'Awarded by the Zimbabwe CEO''s Network.', 2024, true, 'destiny-media/awards/3/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, year=EXCLUDED.year, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.awards (legacy_id, name, description, year, is_published, primary_image_path) VALUES (5, 'ZNCC Micro Entrepreneur Award - Winner', 'Awarded to Kudzai Mundangepfupu, Destiny Travel, by the Zimbabwe National Chamber of Commerce.', 2025, true, 'destiny-media/awards/5/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, year=EXCLUDED.year, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.awards (legacy_id, name, description, year, is_published, primary_image_path) VALUES (6, 'Women in Enterprise Award - 1st Runner Up', 'Tourism Category, awarded to Kudzai Mundangepfupfu.', 2025, true, 'destiny-media/awards/6/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, year=EXCLUDED.year, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.awards (legacy_id, name, description, year, is_published, primary_image_path) VALUES (7, 'National Excellence Hall of Fame', 'Legends in hospitality and customer care.', 2025, true, 'uploads/IMG-20250902-WA0007.jpg') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, year=EXCLUDED.year, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.awards (legacy_id, name, description, year, is_published, primary_image_path) VALUES (3, 'Best Customer Service', 'Gold Winner', 2025, true, 'destiny-media/awards/3/primary.jpg') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, year=EXCLUDED.year, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
INSERT INTO public.awards (legacy_id, name, description, year, is_published, primary_image_path) VALUES (2, 'Hall Of Fame', 'Tourism Legends', 2025, true, 'uploads/IMG-20250902-WA0007.jpg') ON CONFLICT (legacy_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, year=EXCLUDED.year, is_published=EXCLUDED.is_published, primary_image_path=EXCLUDED.primary_image_path, updated_at=timezone('utc', now());
DELETE FROM public.award_images WHERE award_id IN (SELECT id FROM public.awards WHERE legacy_id IS NOT NULL);
INSERT INTO public.award_images (award_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/awards/5/primary.jpg', 'uploads/IMG-20251010-WA0025.jpg', 0 FROM public.awards WHERE legacy_id=5;
INSERT INTO public.award_images (award_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/awards/6/primary.jpg', 'uploads/IMG-20251010-WA0024.jpg', 0 FROM public.awards WHERE legacy_id=6;
INSERT INTO public.award_images (award_id, storage_path, legacy_url, sort_order) SELECT id, 'uploads/IMG-20250902-WA0007.jpg', 'uploads/IMG-20250902-WA0007.jpg', 0 FROM public.awards WHERE legacy_id=7;
INSERT INTO public.award_images (award_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/awards/3/primary.jpg', 'uploads/IMG-20250902-WA0010.jpg', 0 FROM public.awards WHERE legacy_id=3;
INSERT INTO public.award_images (award_id, storage_path, legacy_url, sort_order) SELECT id, 'destiny-media/awards/3/primary.jpg', 'uploads/IMG-20250902-WA0010.jpg', 0 FROM public.awards WHERE legacy_id=4;
INSERT INTO public.award_images (award_id, storage_path, legacy_url, sort_order) SELECT id, 'uploads/IMG-20250902-WA0007.jpg', 'uploads/IMG-20250902-WA0007.jpg', 0 FROM public.awards WHERE legacy_id=2;
COMMIT;

-- >>> END M2 dashboard schema+seed one-paste
