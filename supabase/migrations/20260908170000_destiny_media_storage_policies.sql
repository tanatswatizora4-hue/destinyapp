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
