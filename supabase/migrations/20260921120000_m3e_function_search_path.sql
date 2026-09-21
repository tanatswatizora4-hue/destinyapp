-- M3E: pin search_path on trigger functions (Supabase advisor).
-- Does not change RLS MODEL A. Does not recreate payment tables.
-- CREATE OR REPLACE keeps existing function identity so triggers remain attached.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function public.deny_payment_ledger_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  raise exception 'payment_ledger_entries is append-only';
end;
$$;

comment on function public.set_updated_at() is
  'M3E: updated_at trigger helper. search_path pinned to public.';

comment on function public.deny_payment_ledger_mutation() is
  'M3E: append-only ledger guard. search_path pinned to public.';
