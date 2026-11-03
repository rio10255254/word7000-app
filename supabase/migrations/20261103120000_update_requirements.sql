-- The oldest app version still allowed to run. Posted by the "Broadcast a
-- message" workflow (require_version); the app reads the newest live row and,
-- when it is older, shows a screen that only leads to updating.
create table if not exists public.update_requirements (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  -- e.g. 2.0.3; with min_build, builds of that same version below it too.
  min_version text not null check (min_version ~ '^[0-9]+(\.[0-9]+){0,2}$'),
  min_build integer check (min_build is null or min_build > 0),
  message_zh text not null default '' check (char_length(message_zh) <= 300),
  message_en text not null default '' check (char_length(message_en) <= 300),
  active boolean not null default true
);

alter table public.update_requirements enable row level security;

drop policy if exists "Live update requirements are public" on public.update_requirements;
create policy "Live update requirements are public" on public.update_requirements
  for select to anon, authenticated
  using (active);

revoke all on public.update_requirements from anon, authenticated;
grant select on public.update_requirements to anon, authenticated;

-- An announcement's link can also be "update": a key that opens TestFlight
-- or the App Store, to ask for an update without forcing it.
alter table public.announcements drop constraint if exists announcements_link_check;
alter table public.announcements add constraint announcements_link_check
  check (link is null or link in ('plus', 'update') or link ~ '^https://');
