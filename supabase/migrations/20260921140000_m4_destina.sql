-- M4 Destina production assistant
-- Project: xchddfpfzrzhlbbmyhyn
-- RLS MODEL A: enable RLS, no anon/authenticated policies.
-- Edge Function destina-api uses service_role after authorization.

create table if not exists public.destina_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  anon_session_hash text,
  status text not null default 'active',
  trip_state jsonb not null default '{}'::jsonb,
  last_handoff_at timestamptz,
  last_enquiry_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint destina_conversations_status_check
    check (status in ('active', 'handed_off', 'closed')),
  constraint destina_conversations_owner_check
    check (user_id is not null or anon_session_hash is not null)
);

create index if not exists destina_conversations_user_updated_idx
  on public.destina_conversations (user_id, updated_at desc);

create index if not exists destina_conversations_anon_hash_idx
  on public.destina_conversations (anon_session_hash, updated_at desc)
  where anon_session_hash is not null;

create table if not exists public.destina_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.destina_conversations (id) on delete cascade,
  role text not null,
  content text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  constraint destina_messages_role_check
    check (role in ('user', 'assistant', 'system', 'tool'))
);

create index if not exists destina_messages_conversation_created_idx
  on public.destina_messages (conversation_id, created_at);

create table if not exists public.destina_tool_runs (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.destina_conversations (id) on delete cascade,
  message_id uuid references public.destina_messages (id) on delete set null,
  tool_name text not null,
  arguments jsonb not null default '{}'::jsonb,
  result_summary jsonb not null default '{}'::jsonb,
  status text not null default 'ok',
  error_code text,
  duration_ms integer,
  created_at timestamptz not null default timezone('utc', now()),
  constraint destina_tool_runs_status_check
    check (status in ('ok', 'error', 'rejected', 'needs_input', 'auth_required'))
);

create index if not exists destina_tool_runs_conversation_created_idx
  on public.destina_tool_runs (conversation_id, created_at desc);

create table if not exists public.destina_events (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid
    references public.destina_conversations (id) on delete cascade,
  event_type text not null,
  actor_type text not null default 'system',
  actor_user_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists destina_events_conversation_created_idx
  on public.destina_events (conversation_id, created_at desc);

drop trigger if exists destina_conversations_set_updated_at
  on public.destina_conversations;
create trigger destina_conversations_set_updated_at
before update on public.destina_conversations
for each row execute function public.set_updated_at();

alter table public.destina_conversations enable row level security;
alter table public.destina_messages enable row level security;
alter table public.destina_tool_runs enable row level security;
alter table public.destina_events enable row level security;

comment on table public.destina_conversations is
  'M4 Destina chats. RLS MODEL A: no client policies. destina-api (service_role) after session/JWT checks. anon_session_hash is SHA-256 of an unguessable client session id — never the raw id.';

comment on table public.destina_messages is
  'M4 Destina messages. Do not store provider secrets or raw Travelport payloads.';

comment on table public.destina_tool_runs is
  'M4 Destina allowlisted tool executions. arguments/results are compact summaries only.';

comment on table public.destina_events is
  'M4 Destina operational audit (model, tools, handoff, enquiry). No secrets.';
