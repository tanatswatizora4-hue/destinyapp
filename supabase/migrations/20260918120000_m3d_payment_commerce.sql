-- M3D: Payment-ready commerce (provider-neutral).
-- RLS MODEL A: enable RLS, no anon/authenticated policies.
-- Edge Functions write via service_role after trusted verification.
-- Monetary columns are numeric(12,2). Never float4/float8 for money.
-- Platform technology fee defaults to ZERO. No personal payouts.

-- ---------------------------------------------------------------------------
-- Merchants (Destiny Travel is merchant #1; not a multi-tenant product)
-- ---------------------------------------------------------------------------
create table if not exists public.merchants (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  display_name text not null,
  default_currency text not null default 'USD',
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists merchants_active_slug_idx
  on public.merchants (is_active, slug);

drop trigger if exists merchants_set_updated_at on public.merchants;
create trigger merchants_set_updated_at
  before update on public.merchants
  for each row execute function public.set_updated_at();

alter table public.merchants enable row level security;

comment on table public.merchants is
  'M3D merchant registry. Destiny Travel is merchant #1. Edge Function only.';

-- ---------------------------------------------------------------------------
-- Server-side fee / provider configuration (never accept from Flutter)
-- ---------------------------------------------------------------------------
create table if not exists public.payment_merchant_config (
  merchant_id uuid primary key references public.merchants (id) on delete cascade,
  platform_fee_percent numeric(8, 4) not null default 0
    check (platform_fee_percent >= 0 and platform_fee_percent <= 100),
  platform_fee_fixed numeric(12, 2) not null default 0
    check (platform_fee_fixed >= 0),
  processor_fee_percent numeric(8, 4) not null default 0
    check (processor_fee_percent >= 0 and processor_fee_percent <= 100),
  processor_fee_fixed numeric(12, 2) not null default 0
    check (processor_fee_fixed >= 0),
  default_provider text not null default 'mock',
  updated_at timestamptz not null default timezone('utc', now())
);

drop trigger if exists payment_merchant_config_set_updated_at
  on public.payment_merchant_config;
create trigger payment_merchant_config_set_updated_at
  before update on public.payment_merchant_config
  for each row execute function public.set_updated_at();

alter table public.payment_merchant_config enable row level security;

comment on table public.payment_merchant_config is
  'M3D trusted fee config. Platform fee MUST default to 0. Never client-supplied.';

comment on column public.payment_merchant_config.platform_fee_percent is
  'Platform/technology fee percent. Default 0. No personal percentages.';

comment on column public.payment_merchant_config.platform_fee_fixed is
  'Platform/technology fixed fee in currency units. Default 0.';

-- ---------------------------------------------------------------------------
-- Payment intents
-- ---------------------------------------------------------------------------
create table if not exists public.payment_intents (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references public.merchants (id),
  booking_id uuid not null references public.bookings (id),
  customer_user_id uuid not null references auth.users (id),
  currency text not null,
  gross_amount numeric(12, 2) not null check (gross_amount >= 0),
  platform_fee numeric(12, 2) not null default 0 check (platform_fee >= 0),
  provider_fee numeric(12, 2) not null default 0 check (provider_fee >= 0),
  merchant_net numeric(12, 2) not null check (merchant_net >= 0),
  supplier_payable numeric(12, 2) not null default 0 check (supplier_payable >= 0),
  provider text not null,
  provider_reference text,
  checkout_url text,
  idempotency_key text not null unique,
  payment_status text not null default 'created'
    check (payment_status in (
      'created',
      'pending',
      'requires_action',
      'processing',
      'succeeded',
      'failed',
      'cancelled',
      'expired',
      'refunded',
      'partially_refunded'
    )),
  settlement_status text not null default 'unsettled'
    check (settlement_status in (
      'unsettled',
      'pending',
      'reconciled',
      'discrepancy'
    )),
  expires_at timestamptz,
  confirmed_at timestamptz,
  reconciled_at timestamptz,
  reconciled_by_user_id uuid references auth.users (id) on delete set null,
  reconciliation_note text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists payment_intents_booking_idx
  on public.payment_intents (booking_id, created_at desc);

create index if not exists payment_intents_customer_created_idx
  on public.payment_intents (customer_user_id, created_at desc);

create index if not exists payment_intents_status_idx
  on public.payment_intents (payment_status);

create index if not exists payment_intents_provider_ref_idx
  on public.payment_intents (provider, provider_reference);

create unique index if not exists payment_intents_one_open_per_booking_idx
  on public.payment_intents (booking_id)
  where payment_status in (
    'created',
    'pending',
    'requires_action',
    'processing'
  );

drop trigger if exists payment_intents_set_updated_at on public.payment_intents;
create trigger payment_intents_set_updated_at
  before update on public.payment_intents
  for each row execute function public.set_updated_at();

alter table public.payment_intents enable row level security;

comment on table public.payment_intents is
  'M3D server-authoritative payment intents. Amounts from booking quote + merchant config, never Flutter.';

comment on column public.payment_intents.gross_amount is
  'Authoritative customer charge copied from bookings.quoted_total at intent creation.';

comment on column public.payment_intents.platform_fee is
  'Server-computed platform/technology fee. Default 0.';

comment on column public.payment_intents.metadata is
  'Non-secret provider/session metadata. Never store PAN/CVV/PIN/webhook secrets.';

-- ---------------------------------------------------------------------------
-- Payment attempts
-- ---------------------------------------------------------------------------
create table if not exists public.payment_attempts (
  id uuid primary key default gen_random_uuid(),
  payment_intent_id uuid not null
    references public.payment_intents (id) on delete cascade,
  provider text not null,
  provider_reference text,
  status text not null,
  failure_code text,
  failure_message text,
  result_safe jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists payment_attempts_intent_created_idx
  on public.payment_attempts (payment_intent_id, created_at desc);

alter table public.payment_attempts enable row level security;

comment on table public.payment_attempts is
  'M3D checkout/capture attempts. result_safe must never contain card data or secrets.';

-- ---------------------------------------------------------------------------
-- Provider events / webhooks (idempotent)
-- ---------------------------------------------------------------------------
create table if not exists public.payment_events (
  id uuid primary key default gen_random_uuid(),
  payment_intent_id uuid references public.payment_intents (id) on delete set null,
  provider text not null,
  event_type text not null,
  provider_event_id text,
  payload_safe jsonb not null default '{}'::jsonb,
  verification_status text not null
    check (verification_status in ('verified', 'rejected', 'unsigned', 'ignored')),
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists payment_events_intent_created_idx
  on public.payment_events (payment_intent_id, created_at desc);

create unique index if not exists payment_events_provider_event_uidx
  on public.payment_events (provider, provider_event_id)
  where provider_event_id is not null;

alter table public.payment_events enable row level security;

comment on table public.payment_events is
  'M3D provider webhook/event log. Unique provider_event_id prevents double apply.';

-- ---------------------------------------------------------------------------
-- Refunds
-- ---------------------------------------------------------------------------
create table if not exists public.payment_refunds (
  id uuid primary key default gen_random_uuid(),
  payment_intent_id uuid not null
    references public.payment_intents (id) on delete restrict,
  booking_id uuid not null references public.bookings (id),
  merchant_id uuid not null references public.merchants (id),
  amount numeric(12, 2) not null check (amount > 0),
  currency text not null,
  status text not null default 'requested'
    check (status in (
      'requested',
      'processing',
      'succeeded',
      'failed',
      'cancelled'
    )),
  reason text not null default '',
  provider text not null,
  provider_reference text,
  idempotency_key text not null unique,
  requested_by_user_id uuid references auth.users (id) on delete set null,
  requested_by_type text not null
    check (requested_by_type in ('customer', 'staff', 'system')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists payment_refunds_intent_idx
  on public.payment_refunds (payment_intent_id, created_at desc);

create index if not exists payment_refunds_booking_idx
  on public.payment_refunds (booking_id, created_at desc);

drop trigger if exists payment_refunds_set_updated_at on public.payment_refunds;
create trigger payment_refunds_set_updated_at
  before update on public.payment_refunds
  for each row execute function public.set_updated_at();

alter table public.payment_refunds enable row level security;

comment on table public.payment_refunds is
  'M3D refund requests. Succeeded only after trusted server/provider verification.';

-- ---------------------------------------------------------------------------
-- Append-only ledger
-- ---------------------------------------------------------------------------
create table if not exists public.payment_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  payment_intent_id uuid not null
    references public.payment_intents (id) on delete restrict,
  booking_id uuid references public.bookings (id) on delete restrict,
  merchant_id uuid not null references public.merchants (id),
  refund_id uuid references public.payment_refunds (id) on delete restrict,
  entry_type text not null
    check (entry_type in (
      'customer_payment',
      'processor_fee',
      'platform_fee',
      'merchant_payable',
      'supplier_payable',
      'refund',
      'adjustment'
    )),
  account text not null
    check (account in (
      'customer',
      'processor',
      'platform',
      'merchant',
      'supplier'
    )),
  direction text not null check (direction in ('debit', 'credit')),
  amount numeric(12, 2) not null check (amount > 0),
  currency text not null,
  idempotency_key text not null unique,
  description text not null default '',
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists payment_ledger_intent_idx
  on public.payment_ledger_entries (payment_intent_id, created_at);

create index if not exists payment_ledger_booking_idx
  on public.payment_ledger_entries (booking_id, created_at);

create or replace function public.deny_payment_ledger_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'payment_ledger_entries is append-only';
end;
$$;

drop trigger if exists payment_ledger_entries_no_update
  on public.payment_ledger_entries;
create trigger payment_ledger_entries_no_update
  before update or delete on public.payment_ledger_entries
  for each row execute function public.deny_payment_ledger_mutation();

alter table public.payment_ledger_entries enable row level security;

comment on table public.payment_ledger_entries is
  'M3D append-only financial ledger. Unique idempotency_key prevents double counting.';

-- ---------------------------------------------------------------------------
-- Booking payment_status: allow partial refunds
-- ---------------------------------------------------------------------------
alter table public.bookings drop constraint if exists bookings_payment_status_check;
alter table public.bookings
  add constraint bookings_payment_status_check
  check (payment_status in (
    'none',
    'pending',
    'awaiting_payment',
    'paid',
    'partially_refunded',
    'refunded',
    'failed'
  ));

-- ---------------------------------------------------------------------------
-- Seed Destiny Travel as merchant #1 with ZERO platform fee
-- ---------------------------------------------------------------------------
insert into public.merchants (
  id,
  slug,
  display_name,
  default_currency,
  is_active
) values (
  'a0e1c3d0-0000-4000-8000-000000000001',
  'destiny-travel',
  'Destiny Travel & Tours',
  'USD',
  true
)
on conflict (slug) do nothing;

insert into public.payment_merchant_config (
  merchant_id,
  platform_fee_percent,
  platform_fee_fixed,
  processor_fee_percent,
  processor_fee_fixed,
  default_provider
)
select
  m.id,
  0,
  0,
  0,
  0,
  'mock'
from public.merchants m
where m.slug = 'destiny-travel'
on conflict (merchant_id) do nothing;
