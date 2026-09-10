-- Align inventory updated_at trigger names with live destiny-os production.
-- Live verified names:
--   set_tours_updated_at, set_stays_updated_at,
--   set_vehicles_updated_at, set_awards_updated_at
-- (all call public.set_updated_at)

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

-- Drop legacy scaffold names and any prior aligned names (idempotent).
drop trigger if exists tours_set_updated_at on public.tours;
drop trigger if exists set_tours_updated_at on public.tours;
create trigger set_tours_updated_at
  before update on public.tours
  for each row execute function public.set_updated_at();

drop trigger if exists stays_set_updated_at on public.stays;
drop trigger if exists set_stays_updated_at on public.stays;
create trigger set_stays_updated_at
  before update on public.stays
  for each row execute function public.set_updated_at();

drop trigger if exists vehicles_set_updated_at on public.vehicles;
drop trigger if exists set_vehicles_updated_at on public.vehicles;
create trigger set_vehicles_updated_at
  before update on public.vehicles
  for each row execute function public.set_updated_at();

drop trigger if exists awards_set_updated_at on public.awards;
drop trigger if exists set_awards_updated_at on public.awards;
create trigger set_awards_updated_at
  before update on public.awards
  for each row execute function public.set_updated_at();
