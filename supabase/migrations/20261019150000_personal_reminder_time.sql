-- Backward compatible: existing apps still register a noon reminder.
alter table public.live_activity_devices
  add column if not exists reminder_minute integer not null default 720
  check (reminder_minute between 0 and 1439);

create or replace function public.claim_due_noon_live_activities()
returns setof public.live_activity_devices
language sql
security definer
set search_path = public, pg_catalog
as $$
  with latest_devices as (
    select devices.*,
      row_number() over (partition by push_to_start_token order by updated_at desc, user_id, device_id) as token_priority
    from public.live_activity_devices as devices
  ), due as (
    select devices.user_id, devices.device_id,
      clock.local_now::date as local_date,
      timezone(devices.time_zone, (clock.local_now::date + 1)::timestamp) as expires_at
    from latest_devices as devices
    join pg_catalog.pg_timezone_names as zones on zones.name = devices.time_zone
    cross join lateral (select timezone(zones.name, now()) as local_now) as clock
    cross join lateral (
      select extract(hour from clock.local_now)::integer * 60
        + extract(minute from clock.local_now)::integer as local_minute
    ) as minutes
    where devices.token_priority = 1
      and devices.enabled = true
      and minutes.local_minute >= devices.reminder_minute
      and minutes.local_minute < least(1440, devices.reminder_minute + 60)
      and not (devices.progress_date is not distinct from clock.local_now::date
        and devices.studied_today >= devices.daily_target)
      and devices.noon_activity_started_for_local_date is distinct from clock.local_now::date
  )
  update public.live_activity_devices as devices
  set noon_activity_started_for_local_date = due.local_date,
      noon_activity_expires_at = due.expires_at,
      last_push_error = null,
      updated_at = now()
  from due
  where devices.user_id = due.user_id and devices.device_id = due.device_id
    and devices.noon_activity_started_for_local_date is distinct from due.local_date
  returning devices.*;
$$;

revoke all on function public.claim_due_noon_live_activities() from public, anon, authenticated;
grant execute on function public.claim_due_noon_live_activities() to service_role;
