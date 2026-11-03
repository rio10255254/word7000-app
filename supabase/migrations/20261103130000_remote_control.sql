-- Knowing and steering the versions people run.
--
-- 1. Each install reports its app version when it opens (one row per
--    account, overwritten), so the status check can count who runs what.
-- 2. An announcement (and its push) can be limited to versions below one,
--    e.g. to ask only people on old builds to update.
-- 3. Push devices carry their version too, so a version-limited push only
--    reaches those phones. Phones registered before this (no version) count
--    as old.

create table if not exists word7000_private.app_installs (
  user_id uuid primary key references auth.users(id) on delete cascade,
  app_version text not null check (app_version ~ '^[0-9]+(\.[0-9]+){0,2}$'),
  app_build integer check (app_build is null or app_build > 0),
  os_version text check (os_version is null or char_length(os_version) <= 16),
  language text not null default 'zh' check (language in ('zh', 'en')),
  last_seen timestamptz not null default now()
);

revoke all on word7000_private.app_installs from public, anon, authenticated;

create or replace function public.report_app_version(p_version text, p_build integer, p_os text, p_language text)
returns void
language plpgsql
security definer
set search_path = word7000_private, public, pg_catalog
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'sign in required' using errcode = '42501';
  end if;
  insert into word7000_private.app_installs (user_id, app_version, app_build, os_version, language, last_seen)
  values (me, p_version, p_build, left(p_os, 16), coalesce(p_language, 'zh'), now())
  on conflict (user_id) do update
    set app_version = excluded.app_version, app_build = excluded.app_build,
        os_version = excluded.os_version, language = excluded.language, last_seen = now();
end;
$$;

revoke all on function public.report_app_version(text, integer, text, text) from public, anon;
grant execute on function public.report_app_version(text, integer, text, text) to authenticated;

-- Announcements for older versions only (null: everyone).
alter table public.announcements add column if not exists below_version text
  check (below_version is null or below_version ~ '^[0-9]+(\.[0-9]+){0,2}$');
alter table public.announcements add column if not exists below_build integer
  check (below_build is null or below_build > 0);

-- Push devices remember their app version.
alter table public.push_devices add column if not exists app_version text;
alter table public.push_devices add column if not exists app_build integer;

create or replace function public.register_push_device(p_token text, p_audience text, p_language text,
                                                       p_version text, p_build integer)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'sign in required' using errcode = '42501';
  end if;
  if p_version is not null and p_version !~ '^[0-9]+(\.[0-9]+){0,2}$' then
    raise exception 'invalid version' using errcode = '22023';
  end if;
  insert into public.push_devices (token, user_id, audience, language, app_version, app_build, updated_at)
  values (lower(p_token), me, p_audience, p_language, p_version, p_build, now())
  on conflict (token) do update
    set user_id = excluded.user_id, audience = excluded.audience, language = excluded.language,
        app_version = excluded.app_version, app_build = excluded.app_build, updated_at = now();
  delete from public.push_devices
  where user_id = me
    and token not in (
      select token from public.push_devices where user_id = me order by updated_at desc limit 5
    );
end;
$$;

revoke all on function public.register_push_device(text, text, text, text, integer) from public, anon;
grant execute on function public.register_push_device(text, text, text, text, integer) to authenticated;

-- For the status check (service role only): who runs which version.
create or replace function public.app_version_summary()
returns table (app_version text, app_build integer, installs bigint, seen_last_7_days bigint, push_devices bigint)
language sql
security definer
set search_path = word7000_private, public, pg_catalog
as $$
  with installs as (
    select app_version, app_build, count(*) as installs,
           count(*) filter (where last_seen > now() - interval '7 days') as recent
    from word7000_private.app_installs group by 1, 2
  ), devices as (
    select coalesce(app_version, 'before 2.0.2 (4)') as app_version, app_build, count(*) as devices
    from public.push_devices group by 1, 2
  )
  select coalesce(i.app_version, d.app_version), coalesce(i.app_build, d.app_build),
         coalesce(i.installs, 0), coalesce(i.recent, 0), coalesce(d.devices, 0)
  from installs i full join devices d on d.app_version = i.app_version and d.app_build is not distinct from i.app_build
  order by 1 desc, 2 desc nulls last;
$$;

revoke all on function public.app_version_summary() from public, anon, authenticated;
grant execute on function public.app_version_summary() to service_role;
