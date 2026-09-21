-- M5A: Private customer travel documents (Model A — Edge only).
-- Forward-only. Do NOT use public destiny-media for these files.

-- ---------------------------------------------------------------------------
-- Private storage bucket
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'customer-travel-documents',
  'customer-travel-documents',
  false,
  10485760, -- 10 MiB
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf'
  ]
)
on conflict (id) do update
set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- No anon/authenticated storage policies: deny-by-default.
-- Edge Functions use service_role for controlled upload/download/delete.
drop policy if exists "customer_travel_documents_select" on storage.objects;
drop policy if exists "customer_travel_documents_insert" on storage.objects;
drop policy if exists "customer_travel_documents_update" on storage.objects;
drop policy if exists "customer_travel_documents_delete" on storage.objects;

-- ---------------------------------------------------------------------------
-- Document metadata
-- ---------------------------------------------------------------------------
create table if not exists public.customer_travel_documents (
  id uuid primary key default gen_random_uuid(),
  customer_user_id uuid not null references auth.users (id) on delete cascade,
  document_type text not null
    check (document_type in (
      'passport',
      'visa',
      'national_id',
      'residence_permit',
      'vaccination_certificate',
      'other'
    )),
  display_name text not null default '',
  storage_bucket text not null default 'customer-travel-documents'
    check (storage_bucket = 'customer-travel-documents'),
  storage_path text not null,
  mime_type text not null
    check (mime_type in (
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/pdf'
    )),
  file_size integer not null check (file_size > 0 and file_size <= 10485760),
  issuing_country text,
  issue_date date,
  expiry_date date,
  verification_status text not null default 'unverified'
    check (verification_status in (
      'unverified',
      'pending_review',
      'verified',
      'rejected'
    )),
  verification_note text not null default '',
  verified_at timestamptz,
  verified_by_user_id uuid references auth.users (id) on delete set null,
  upload_status text not null default 'pending'
    check (upload_status in ('pending', 'ready', 'failed')),
  archived_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint customer_travel_documents_path_unique unique (storage_bucket, storage_path)
);

create index if not exists customer_travel_documents_owner_created_idx
  on public.customer_travel_documents (customer_user_id, created_at desc)
  where archived_at is null;

create index if not exists customer_travel_documents_type_idx
  on public.customer_travel_documents (customer_user_id, document_type)
  where archived_at is null;

drop trigger if exists customer_travel_documents_set_updated_at
  on public.customer_travel_documents;
create trigger customer_travel_documents_set_updated_at
  before update on public.customer_travel_documents
  for each row execute function public.set_updated_at();

alter table public.customer_travel_documents enable row level security;
-- Intentionally no anon/authenticated policies (Model A).

comment on table public.customer_travel_documents is
  'M5A: private travel-document metadata. Files in private customer-travel-documents bucket. Edge Functions only.';

-- ---------------------------------------------------------------------------
-- Document access / mutation audit (no file contents)
-- ---------------------------------------------------------------------------
create table if not exists public.customer_travel_document_events (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null
    references public.customer_travel_documents (id) on delete cascade,
  event_type text not null,
  actor_type text not null
    check (actor_type in ('customer', 'staff', 'system')),
  actor_user_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists customer_travel_document_events_doc_created_idx
  on public.customer_travel_document_events (document_id, created_at desc);

alter table public.customer_travel_document_events enable row level security;

comment on table public.customer_travel_document_events is
  'M5A: append-only document audit (upload/view/delete/verify). No secrets or file bytes.';
