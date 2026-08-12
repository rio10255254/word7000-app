alter table public.daily_active_users
  add column if not exists account_type text not null default 'registered';

update public.daily_active_users as activity
set account_type = case when users.is_anonymous then 'guest' else 'registered' end
from auth.users as users
where users.id = activity.user_id;

alter table public.daily_active_users
  drop constraint if exists daily_active_users_account_type_check;

alter table public.daily_active_users
  add constraint daily_active_users_account_type_check
  check (account_type in ('guest', 'registered'));

create or replace function public.set_daily_active_user_account_type()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  select case when users.is_anonymous then 'guest' else 'registered' end
  into new.account_type
  from auth.users as users
  where users.id = new.user_id;

  new.account_type := coalesce(new.account_type, 'registered');
  return new;
end;
$$;

revoke all on function public.set_daily_active_user_account_type() from public, anon, authenticated;

drop trigger if exists daily_active_users_account_type_trigger on public.daily_active_users;
create trigger daily_active_users_account_type_trigger
  before insert or update on public.daily_active_users
  for each row execute function public.set_daily_active_user_account_type();

create index if not exists daily_active_users_account_type_date_idx
  on public.daily_active_users (account_type, activity_date desc);

create schema if not exists word7000_private;

create or replace view word7000_private.daily_metrics as
select
  activity_date,
  count(distinct user_id) as active_users,
  count(distinct user_id) filter (where account_type = 'guest') as guest_users,
  count(distinct user_id) filter (where account_type = 'registered') as registered_users,
  max(last_seen_at) as latest_activity_at
from public.daily_active_users
group by activity_date
order by activity_date desc;

revoke all on schema word7000_private from public, anon, authenticated;
revoke all on word7000_private.daily_metrics from public, anon, authenticated;

create or replace function public.claim_due_streak_live_activities()
returns setof public.live_activity_devices
language sql
security definer
set search_path = public
as $$
  with due as (
    select
      user_id,
      device_id,
      row_number() over (partition by push_to_start_token order by updated_at desc) as token_priority
    from public.live_activity_devices
    where enabled = true
      and streak > 0
      and streak_expires_at > now()
      and streak_expires_at <= now() + interval '1 hour'
      and activity_started_for_expires_at is distinct from streak_expires_at
  )
  update public.live_activity_devices as devices
  set
    activity_started_for_expires_at = devices.streak_expires_at,
    last_push_error = null,
    updated_at = now()
  from due
  where devices.user_id = due.user_id
    and devices.device_id = due.device_id
    and due.token_priority = 1
  returning devices.*;
$$;

revoke all on function public.claim_due_streak_live_activities() from public, anon, authenticated;
grant execute on function public.claim_due_streak_live_activities() to service_role;
