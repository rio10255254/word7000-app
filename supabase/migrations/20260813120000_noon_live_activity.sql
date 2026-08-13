alter table public.live_activity_devices
  add column if not exists daily_target integer not null default 20,
  add column if not exists studied_today integer not null default 0,
  add column if not exists progress_date date,
  add column if not exists noon_activity_started_for_local_date date,
  add column if not exists noon_activity_expires_at timestamptz;

alter table public.live_activity_devices
  drop constraint if exists live_activity_devices_daily_target_check,
  drop constraint if exists live_activity_devices_studied_today_check;

alter table public.live_activity_devices
  add constraint live_activity_devices_daily_target_check check (daily_target > 0),
  add constraint live_activity_devices_studied_today_check check (studied_today >= 0);

create or replace function public.claim_due_noon_live_activities()
returns setof public.live_activity_devices
language sql
security definer
set search_path = public, pg_catalog
as $$
  with due as (
    select
      devices.user_id,
      devices.device_id,
      clock.local_now::date as local_date,
      timezone(devices.time_zone, (clock.local_now::date + 1)::timestamp) as expires_at,
      row_number() over (partition by devices.push_to_start_token order by devices.updated_at desc) as token_priority
    from public.live_activity_devices as devices
    join pg_catalog.pg_timezone_names as zones on zones.name = devices.time_zone
    cross join lateral (
      select timezone(zones.name, now()) as local_now
    ) as clock
    where devices.enabled = true
      and clock.local_now::time >= time '12:00'
      and clock.local_now::time < time '13:00'
      and devices.noon_activity_started_for_local_date is distinct from clock.local_now::date
  )
  update public.live_activity_devices as devices
  set
    noon_activity_started_for_local_date = due.local_date,
    noon_activity_expires_at = due.expires_at,
    last_push_error = null,
    updated_at = now()
  from due
  where devices.user_id = due.user_id
    and devices.device_id = due.device_id
    and due.token_priority = 1
  returning devices.*;
$$;

revoke all on function public.claim_due_noon_live_activities() from public, anon, authenticated;
grant execute on function public.claim_due_noon_live_activities() to service_role;
