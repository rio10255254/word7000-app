-- Apply after 20261019150000. Intentionally contains no transaction control:
-- the migration runner may wrap this entire migration in its own transaction.
-- Historical updated_at mixed registration and cron writes. Until a fresh
-- registration establishes ownership, quarantine ambiguous preexisting token
-- groups. This changes only delivery rows, never the user's app preferences.
alter table public.live_activity_devices
  add column if not exists registration_updated_at timestamptz;

with ambiguous_tokens as (
  select push_to_start_token
  from public.live_activity_devices
  group by push_to_start_token
  having count(*) > 1
)
update public.live_activity_devices as devices
set enabled = false
from ambiguous_tokens
where devices.push_to_start_token = ambiguous_tokens.push_to_start_token
  and devices.registration_updated_at is null;

-- NULL marks rows predating this migration. Reapplying must not disable fresh
-- registrations or replace their owner timestamp with a subsequent cron write.
update public.live_activity_devices
set registration_updated_at = updated_at
where registration_updated_at is null;

alter table public.live_activity_devices
  alter column registration_updated_at set default now(),
  alter column registration_updated_at set not null;

create index if not exists live_activity_devices_token_registration_idx
  on public.live_activity_devices (push_to_start_token, registration_updated_at desc, user_id, device_id);

create schema if not exists word7000_private;
revoke all on schema word7000_private from public, anon, authenticated;

create or replace function word7000_private.guard_reminder_registration()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  if tg_op = 'INSERT' then
    -- BEFORE INSERT also runs before ON CONFLICT UPDATE. Do not replace
    -- updated_at: EXCLUDED must still carry the original client timestamp.
    new.registration_updated_at := new.updated_at;
  elsif auth.jwt() ->> 'role' = 'authenticated' then
    if new.updated_at = old.registration_updated_at
       and (to_jsonb(new) - array[
         'updated_at', 'registration_updated_at', 'activity_started_for_expires_at',
         'noon_activity_started_for_local_date', 'noon_activity_expires_at', 'last_push_error'
       ]) = (to_jsonb(old) - array[
         'updated_at', 'registration_updated_at', 'activity_started_for_expires_at',
         'noon_activity_started_for_local_date', 'noon_activity_expires_at', 'last_push_error'
       ]) then
      -- A lost response may cause an identical retry. Acknowledge it without
      -- promoting ownership or rolling back any intervening cron metadata.
      return old;
    end if;
    if new.updated_at <= old.registration_updated_at then
      return null;
    end if;
    new.registration_updated_at := new.updated_at;
  else
    -- Cron/error reporting is not a new owner registration. Never trust a
    -- writable row field to distinguish a client from the trusted JWT role.
    new.registration_updated_at := old.registration_updated_at;
  end if;
  return new;
end;
$$;

revoke all on function word7000_private.guard_reminder_registration()
  from public, anon, authenticated, service_role;

drop trigger if exists live_activity_devices_registration_guard on public.live_activity_devices;
create trigger live_activity_devices_registration_guard
  before insert or update on public.live_activity_devices
  for each row execute function word7000_private.guard_reminder_registration();

create or replace function public.claim_due_streak_live_activities()
returns setof public.live_activity_devices
language sql
security definer
set search_path = pg_catalog
as $$
  with latest_devices as (
    select devices.*,
      row_number() over (
        partition by push_to_start_token
        order by registration_updated_at desc, user_id, device_id
      ) as token_priority
    from public.live_activity_devices as devices
  ), due as (
    select user_id, device_id
    from latest_devices
    where token_priority = 1
      and enabled = true
      and streak > 0
      and streak_expires_at > now()
      and streak_expires_at <= now() + interval '1 hour'
      and activity_started_for_expires_at is distinct from streak_expires_at
  )
  update public.live_activity_devices as devices
  set activity_started_for_expires_at = devices.streak_expires_at,
      last_push_error = null,
      updated_at = now()
  from due
  where devices.user_id = due.user_id and devices.device_id = due.device_id
    and devices.activity_started_for_expires_at is distinct from devices.streak_expires_at
  returning devices.*;
$$;

create or replace function public.claim_due_noon_live_activities()
returns setof public.live_activity_devices
language sql
security definer
set search_path = pg_catalog
as $$
  with latest_devices as (
    select devices.*,
      row_number() over (
        partition by push_to_start_token
        order by registration_updated_at desc, user_id, device_id
      ) as token_priority
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

revoke all on function public.claim_due_streak_live_activities() from public, anon, authenticated;
revoke all on function public.claim_due_noon_live_activities() from public, anon, authenticated;
grant execute on function public.claim_due_streak_live_activities() to service_role;
grant execute on function public.claim_due_noon_live_activities() to service_role;

-- Legacy clients omit streakFreezeDate when replacing the progress document.
-- Keep this reconciliation in step with the Swift/TS StreakProtection rules.
create or replace function word7000_private.progress_calendar_date(value text)
returns date
language plpgsql
immutable
strict
set search_path = pg_catalog
as $$
begin
  if value !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    return null;
  end if;
  return value::date;
exception
  when invalid_datetime_format or datetime_field_overflow then
    return null;
end;
$$;

create or replace function word7000_private.preserve_profile_streak()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  freeze_day date;
  last_day date;
  observed_day date;
  source_day date;
  missed_day date;
  source_state jsonb;
  source_count integer;
  gap integer;
  reconciled_count integer := 0;
  protected_count integer := 0;
begin
  if new.progress is not distinct from old.progress
     or jsonb_typeof(new.progress) is distinct from 'object'
     or jsonb_typeof(old.progress) is distinct from 'object' then
    return new;
  end if;

  freeze_day := greatest(
    word7000_private.progress_calendar_date(old.progress ->> 'streakFreezeDate'),
    word7000_private.progress_calendar_date(new.progress ->> 'streakFreezeDate'));
  last_day := greatest(
    word7000_private.progress_calendar_date(old.progress ->> 'lastStudyDate'),
    word7000_private.progress_calendar_date(new.progress ->> 'lastStudyDate'));

  if last_day is not null then
    for source_state in select old.progress union all select new.progress loop
      source_day := word7000_private.progress_calendar_date(source_state ->> 'lastStudyDate');
      -- A malformed legacy count is not evidence for recovering a streak.
      if source_day is null
         or jsonb_typeof(source_state -> 'streak') is distinct from 'number'
         or (source_state ->> 'streak') !~ '^[0-9]{1,10}$' then
        continue;
      end if;
      if (source_state ->> 'streak')::numeric not between 1 and 2147483646 then
        continue;
      end if;
      source_count := (source_state ->> 'streak')::integer;
      gap := last_day - source_day;
      if gap in (0, 1) then
        reconciled_count := greatest(reconciled_count, source_count + gap);
      elsif gap = 2 then
        protected_count := greatest(protected_count, source_count + 1);
      end if;
    end loop;

    -- Do not spend protection for an older snapshot when a newer count
    -- already proves a longer streak (e.g. Oct 1:5, Oct 3:7 needs no freeze).
    missed_day := last_day - 1;
    if protected_count > reconciled_count
       and (freeze_day is null or freeze_day = missed_day or missed_day - freeze_day >= 7) then
      reconciled_count := protected_count;
      freeze_day := missed_day;
    end if;

    observed_day := greatest(last_day,
      word7000_private.progress_calendar_date(old.progress ->> 'dailyProgressDate'),
      word7000_private.progress_calendar_date(new.progress ->> 'dailyProgressDate'));
    gap := observed_day - last_day;
    if gap >= 2 then
      missed_day := observed_day - 1;
      if gap = 2 and reconciled_count > 0
         and (freeze_day is null or freeze_day = missed_day or missed_day - freeze_day >= 7) then
        freeze_day := missed_day;
      else
        reconciled_count := 0;
      end if;
    end if;

    new.progress := jsonb_set(new.progress, '{lastStudyDate}', to_jsonb(to_char(last_day, 'YYYY-MM-DD')));
    new.progress := jsonb_set(new.progress, '{streak}', to_jsonb(reconciled_count));
  end if;

  if freeze_day is not null then
    new.progress := jsonb_set(new.progress, '{streakFreezeDate}', to_jsonb(to_char(freeze_day, 'YYYY-MM-DD')));
  else
    new.progress := new.progress - 'streakFreezeDate';
  end if;
  return new;
end;
$$;

revoke all on function word7000_private.progress_calendar_date(text)
  from public, anon, authenticated, service_role;
revoke all on function word7000_private.preserve_profile_streak()
  from public, anon, authenticated, service_role;

drop trigger if exists profiles_preserve_streak on public.profiles;
create trigger profiles_preserve_streak
  before update of progress on public.profiles
  for each row execute function word7000_private.preserve_profile_streak();
