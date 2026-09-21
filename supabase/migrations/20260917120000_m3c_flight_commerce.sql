-- M3C: provider-neutral flight commerce metadata on existing enquiry/booking
-- tables. Does not create a second booking system. RLS MODEL A unchanged:
-- no anon/authenticated policies; Edge Functions write via service_role.

-- ---------------------------------------------------------------------------
-- Enquiries: snapshot of a selected/validated flight offer
-- ---------------------------------------------------------------------------
alter table public.enquiries
  add column if not exists provider text;

alter table public.enquiries
  add column if not exists provider_offer_ref text;

alter table public.enquiries
  add column if not exists provider_order_ref text;

alter table public.enquiries
  add column if not exists itinerary_snapshot jsonb not null default '{}'::jsonb;

alter table public.enquiries
  add column if not exists validated_amount numeric(12, 2);

alter table public.enquiries
  add column if not exists validated_currency text;

alter table public.enquiries
  add column if not exists offer_expires_at timestamptz;

alter table public.enquiries
  add column if not exists passenger_summary jsonb not null default '{}'::jsonb;

alter table public.enquiries
  add column if not exists provider_status text;

create index if not exists enquiries_kind_created_idx
  on public.enquiries (kind, created_at desc);

comment on column public.enquiries.provider is
  'M3C provider-neutral source (e.g. travelport). Never store provider secrets.';

comment on column public.enquiries.provider_offer_ref is
  'Provider offer/transaction reference for reconciliation. Not a ticket.';

comment on column public.enquiries.itinerary_snapshot is
  'Normalized Destiny itinerary snapshot. Not raw provider search dumps.';

comment on column public.enquiries.validated_amount is
  'Last server-side provider-validated amount. Not a Destiny quote or payment.';

-- ---------------------------------------------------------------------------
-- Bookings: same provider-neutral columns when a flight enquiry converts
-- ---------------------------------------------------------------------------
alter table public.bookings
  add column if not exists provider text;

alter table public.bookings
  add column if not exists provider_offer_ref text;

alter table public.bookings
  add column if not exists provider_order_ref text;

alter table public.bookings
  add column if not exists itinerary_snapshot jsonb not null default '{}'::jsonb;

alter table public.bookings
  add column if not exists validated_amount numeric(12, 2);

alter table public.bookings
  add column if not exists validated_currency text;

alter table public.bookings
  add column if not exists offer_expires_at timestamptz;

alter table public.bookings
  add column if not exists passenger_summary jsonb not null default '{}'::jsonb;

alter table public.bookings
  add column if not exists provider_status text;

create index if not exists bookings_item_type_created_idx
  on public.bookings (item_type, created_at desc);

comment on column public.bookings.provider is
  'M3C provider-neutral source (e.g. travelport).';

comment on column public.bookings.provider_offer_ref is
  'Provider offer/transaction reference. Not proof of ticketing.';

comment on column public.bookings.provider_order_ref is
  'Future provider PNR/order locator. Empty until a real order exists.';

comment on column public.bookings.itinerary_snapshot is
  'Normalized Destiny itinerary snapshot for customer history and staff ops.';

comment on column public.bookings.validated_amount is
  'Last server-validated provider amount. quoted_total remains Destiny-authoritative.';

comment on column public.bookings.provider_status is
  'Provider lifecycle metadata (search|priced|enquiry). Never a fake ticketed state.';
