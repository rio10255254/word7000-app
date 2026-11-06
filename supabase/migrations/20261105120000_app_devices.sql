-- Every phone that runs the app, not only every account: one row per phone,
-- keyed by the app's per-vendor device id (it identifies the phone to this
-- app only), with its model, so the status check can list each phone with
-- its model, iOS and app version. Deleting the account deletes its phones.

create table if not exists word7000_private.app_devices (
  device_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  model text not null check (char_length(model) <= 32 and model ~ '^[A-Za-z0-9,._-]+$'),
  app_version text not null check (app_version ~ '^[0-9]+(\.[0-9]+){0,2}$'),
  app_build integer check (app_build is null or app_build > 0),
  os_version text check (os_version is null or char_length(os_version) <= 16),
  language text not null default 'zh' check (language in ('zh', 'en')),
  first_seen timestamptz not null default now(),
  last_seen timestamptz not null default now()
);

revoke all on word7000_private.app_devices from public, anon, authenticated;

-- Newer apps also say which phone this is; older ones keep calling the
-- four-argument version, which still records the account's version.
create or replace function public.report_app_version(p_version text, p_build integer, p_os text, p_language text,
                                                     p_device uuid, p_model text)
returns void
language plpgsql
security definer
set search_path = word7000_private, public, pg_catalog
as $$
declare
  me uuid := auth.uid();
begin
  perform public.report_app_version(p_version, p_build, p_os, p_language);
  if p_device is null then return; end if;
  if p_model is null or char_length(p_model) > 32 or p_model !~ '^[A-Za-z0-9,._-]+$' then
    raise exception 'invalid model' using errcode = '22023';
  end if;
  insert into word7000_private.app_devices (device_id, user_id, model, app_version, app_build, os_version, language, last_seen)
  values (p_device, me, p_model, p_version, p_build, left(p_os, 16), coalesce(p_language, 'zh'), now())
  on conflict (device_id) do update
    set user_id = excluded.user_id, model = excluded.model, app_version = excluded.app_version,
        app_build = excluded.app_build, os_version = excluded.os_version, language = excluded.language,
        last_seen = now();
end;
$$;

revoke all on function public.report_app_version(text, integer, text, text, uuid, text) from public, anon;
grant execute on function public.report_app_version(text, integer, text, text, uuid, text) to authenticated;

-- For the developer's status check (service role only): each phone, newest
-- first, without who owns it beyond guest or Apple account.
create or replace function public.app_device_list()
returns table (model text, app_version text, app_build integer, os_version text, language text,
               account text, first_seen timestamptz, last_seen timestamptz)
language sql
stable
security definer
set search_path = word7000_private, public, pg_catalog
as $$
  select d.model, d.app_version, d.app_build, d.os_version, d.language,
         case when coalesce(u.is_anonymous, false) then 'guest' else 'apple' end,
         d.first_seen, d.last_seen
  from word7000_private.app_devices d
  join auth.users u on u.id = d.user_id
  order by d.last_seen desc
$$;

revoke all on function public.app_device_list() from public, anon, authenticated;
grant execute on function public.app_device_list() to service_role;
