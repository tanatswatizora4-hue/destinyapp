-- M5B/C: CRM staff notes, ops audit, enquiry follow-ups, expanded lifecycle.
-- Additive / forward-only. Model A (RLS on, no client policies).

-- ---------------------------------------------------------------------------
-- Expanded enquiry lifecycle (keeps existing statuses)
-- ---------------------------------------------------------------------------
alter table public.enquiries drop constraint if exists enquiries_status_check;
alter table public.enquiries
  add constraint enquiries_status_check
  check (status in (
    'received',
    'in_review',
    'contacted',
    'researching',
    'quoted',
    'awaiting_customer',
    'converted',
    'closed',
    'cancelled'
  ));

comment on column public.enquiries.status is
  'M5C lifecycle: received|in_review|contacted|researching|quoted|awaiting_customer|converted|closed|cancelled';

alter table public.enquiries
  add column if not exists next_follow_up_at timestamptz;

alter table public.enquiries
  add column if not exists follow_up_note text not null default '';

alter table public.enquiries
  add column if not exists follow_up_completed_at timestamptz;

alter table public.enquiries
  add column if not exists priority text not null default 'normal';

do $$
begin
  alter table public.enquiries
    add constraint enquiries_priority_check
    check (priority in ('low', 'normal', 'high', 'urgent'));
exception
  when duplicate_object then null;
end $$;

create index if not exists enquiries_follow_up_due_idx
  on public.enquiries (next_follow_up_at)
  where next_follow_up_at is not null
    and follow_up_completed_at is null
    and status not in ('converted', 'closed', 'cancelled');

create index if not exists enquiries_status_updated_idx
  on public.enquiries (status, updated_at desc);

create index if not exists enquiries_assigned_user_status_idx
  on public.enquiries (assigned_staff_user_id, status, updated_at desc);

create index if not exists customer_profiles_full_name_lower_idx
  on public.customer_profiles (lower(full_name));

create index if not exists customer_profiles_email_lower_idx
  on public.customer_profiles (lower(email));

-- ---------------------------------------------------------------------------
-- Staff-only customer notes (CRM)
-- ---------------------------------------------------------------------------
create table if not exists public.staff_customer_notes (
  id uuid primary key default gen_random_uuid(),
  customer_user_id uuid not null references auth.users (id) on delete cascade,
  author_staff_user_id uuid not null references auth.users (id) on delete restrict,
  author_staff_row_id uuid references public.staff_users (id) on delete set null,
  body text not null check (char_length(body) between 1 and 4000),
  archived_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists staff_customer_notes_customer_created_idx
  on public.staff_customer_notes (customer_user_id, created_at desc)
  where archived_at is null;

drop trigger if exists staff_customer_notes_set_updated_at on public.staff_customer_notes;
create trigger staff_customer_notes_set_updated_at
  before update on public.staff_customer_notes
  for each row execute function public.set_updated_at();

alter table public.staff_customer_notes enable row level security;

comment on table public.staff_customer_notes is
  'M5B: staff-only CRM notes. Author is server-derived. Customers never read.';

-- ---------------------------------------------------------------------------
-- Cross-cutting ops audit
-- ---------------------------------------------------------------------------
create table if not exists public.ops_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid,
  actor_type text not null
    check (actor_type in ('staff', 'system', 'customer')),
  action text not null,
  entity_type text not null,
  entity_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists ops_audit_events_created_idx
  on public.ops_audit_events (created_at desc);

create index if not exists ops_audit_events_entity_idx
  on public.ops_audit_events (entity_type, entity_id, created_at desc);

alter table public.ops_audit_events enable row level security;

comment on table public.ops_audit_events is
  'M5E: append-only operational audit. No secrets or document bytes.';
