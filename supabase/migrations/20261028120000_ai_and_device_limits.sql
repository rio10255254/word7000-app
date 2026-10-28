-- Security limits before the 1.0 release.
--
-- 1. The AI quota is counted only by the `ai` edge function (service role),
--    never by the app directly, and a site-wide daily total backs a hard cap
--    on what Claude can cost in one day.
-- 2. A Plus subscription proves membership for at most three accounts a
--    month, and a refund or revocation reported by the App Store ends it.
-- 3. Live Activity registrations are bounded per learner and must carry an
--    APNs-shaped token, so a script cannot fill the reminder queue.
-- 4. Synced progress has a size ceiling, and activity days stay near today.

-- 1. AI quota -----------------------------------------------------------------

create table if not exists word7000_private.ai_daily_totals (
  usage_date date primary key,
  requests integer not null default 0
);

revoke all on word7000_private.ai_daily_totals from public, anon, authenticated;

create or replace function public.consume_ai_quota_for(p_user uuid)
returns jsonb
language plpgsql
security definer
set search_path = word7000_private, pg_catalog
as $$
declare
  today date := (timezone('utc', now()))::date;
  used integer;
  total integer;
  started timestamptz;
begin
  if p_user is null then
    raise exception 'user required' using errcode = '22004';
  end if;
  insert into word7000_private.ai_members (user_id) values (p_user)
  on conflict (user_id) do nothing;
  select first_seen into started from word7000_private.ai_members where user_id = p_user;

  insert into word7000_private.ai_usage as usage (user_id, usage_date, requests)
  values (p_user, today, 1)
  on conflict (user_id, usage_date) do update set requests = usage.requests + 1
  returning usage.requests into used;
  delete from word7000_private.ai_usage where user_id = p_user and usage_date < today - 7;

  insert into word7000_private.ai_daily_totals as totals (usage_date, requests)
  values (today, 1)
  on conflict (usage_date) do update set requests = totals.requests + 1
  returning totals.requests into total;

  return jsonb_build_object('requests', used, 'first_seen', started, 'total', total);
end;
$$;

revoke all on function public.consume_ai_quota_for(uuid) from public, anon, authenticated;
grant execute on function public.consume_ai_quota_for(uuid) to service_role;

-- The app never called these itself; only the edge function did, with the
-- learner's session. Nothing outside the service role may count requests now.
revoke all on function public.consume_ai_quota() from public, anon, authenticated;
drop function if exists public.consume_ai_request();

-- 2. Plus subscriptions ---------------------------------------------------------

create table if not exists word7000_private.plus_claims (
  original_transaction_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  last_used timestamptz not null default now(),
  primary key (original_transaction_id, user_id)
);

create table if not exists word7000_private.plus_revocations (
  original_transaction_id text primary key,
  notification_type text not null,
  revoked_at timestamptz not null default now()
);

revoke all on word7000_private.plus_claims from public, anon, authenticated;
revoke all on word7000_private.plus_revocations from public, anon, authenticated;

-- True when this subscription may stand for this account: not refunded, and
-- either already used by it or by fewer than three accounts in the last 30
-- days (a learner who signs in on a new account keeps Plus; a subscription
-- passed around does not).
create or replace function public.claim_plus_for(p_user uuid, p_original_transaction_id text)
returns boolean
language plpgsql
security definer
set search_path = word7000_private, pg_catalog
as $$
declare
  others integer;
begin
  if p_user is null or p_original_transaction_id is null or p_original_transaction_id !~ '^[0-9]{1,32}$' then
    return false;
  end if;
  if exists (select 1 from word7000_private.plus_revocations where original_transaction_id = p_original_transaction_id) then
    return false;
  end if;
  update word7000_private.plus_claims set last_used = now()
  where original_transaction_id = p_original_transaction_id and user_id = p_user;
  if found then
    return true;
  end if;
  select count(*) into others from word7000_private.plus_claims
  where original_transaction_id = p_original_transaction_id and last_used > now() - interval '30 days';
  if others >= 3 then
    return false;
  end if;
  insert into word7000_private.plus_claims (original_transaction_id, user_id)
  values (p_original_transaction_id, p_user)
  on conflict do nothing;
  return true;
end;
$$;

revoke all on function public.claim_plus_for(uuid, text) from public, anon, authenticated;
grant execute on function public.claim_plus_for(uuid, text) to service_role;

create or replace function public.record_plus_notice(p_original_transaction_id text, p_type text, p_revoked boolean)
returns void
language plpgsql
security definer
set search_path = word7000_private, pg_catalog
as $$
begin
  if p_original_transaction_id !~ '^[0-9]{1,32}$' then
    return;
  end if;
  if p_revoked then
    insert into word7000_private.plus_revocations (original_transaction_id, notification_type)
    values (p_original_transaction_id, left(p_type, 40))
    on conflict (original_transaction_id) do update set notification_type = excluded.notification_type, revoked_at = now();
  else
    delete from word7000_private.plus_revocations where original_transaction_id = p_original_transaction_id;
  end if;
end;
$$;

revoke all on function public.record_plus_notice(text, text, boolean) from public, anon, authenticated;
grant execute on function public.record_plus_notice(text, text, boolean) to service_role;

-- 3. Live Activity registrations ------------------------------------------------

-- Rows that could never be delivered go before the checks, so no later update
-- of an old row trips them; the app registers again with a real token.
delete from public.live_activity_devices
where not (push_to_start_token ~ '^[0-9a-fA-F]+$' and length(push_to_start_token) between 32 and 512)
   or (activity_push_token is not null
       and not (activity_push_token ~ '^[0-9a-fA-F]+$' and length(activity_push_token) between 32 and 512))
   or length(device_id) not between 1 and 100
   or length(time_zone) not between 1 and 64;
update public.live_activity_devices
set last_push_error = left(last_push_error, 600)
where length(last_push_error) > 600;

alter table public.live_activity_devices
  drop constraint if exists live_activity_devices_token_shape,
  drop constraint if exists live_activity_devices_activity_token_shape,
  drop constraint if exists live_activity_devices_device_id_length,
  drop constraint if exists live_activity_devices_time_zone_length,
  drop constraint if exists live_activity_devices_error_length;

alter table public.live_activity_devices
  add constraint live_activity_devices_token_shape
    check (push_to_start_token ~ '^[0-9a-fA-F]+$' and length(push_to_start_token) between 32 and 512) not valid,
  add constraint live_activity_devices_activity_token_shape
    check (activity_push_token is null
      or (activity_push_token ~ '^[0-9a-fA-F]+$' and length(activity_push_token) between 32 and 512)) not valid,
  add constraint live_activity_devices_device_id_length
    check (length(device_id) between 1 and 100) not valid,
  add constraint live_activity_devices_time_zone_length
    check (length(time_zone) between 1 and 64) not valid,
  add constraint live_activity_devices_error_length
    check (last_push_error is null or length(last_push_error) <= 600) not valid;

-- A learner has a handful of iPhones and iPads, not hundreds: a new device
-- replaces the least recently registered ones beyond five, so reinstalls never
-- lock anyone out and a script cannot grow the reminder queue.
create or replace function public.limit_live_activity_devices()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
begin
  -- An upsert of a device already registered is not a new device.
  delete from public.live_activity_devices
  where user_id = new.user_id
    and device_id in (
      select device_id from public.live_activity_devices
      where user_id = new.user_id and device_id <> new.device_id
      order by registration_updated_at desc, device_id
      offset 4
    );
  return new;
end;
$$;

revoke all on function public.limit_live_activity_devices() from public, anon, authenticated;

drop trigger if exists live_activity_devices_limit on public.live_activity_devices;
create trigger live_activity_devices_limit
  before insert on public.live_activity_devices
  for each row execute function public.limit_live_activity_devices();

-- 4. Synced data -----------------------------------------------------------------

alter table public.profiles drop constraint if exists profiles_payload_size;
alter table public.profiles
  add constraint profiles_payload_size
    check (pg_column_size(progress) + pg_column_size(custom_sets) <= 8000000) not valid;

-- The app records today in the learner's own time zone, at most a day from
-- UTC; other dates would only skew the daily metrics.
drop policy if exists "Users can insert their own daily activity" on public.daily_active_users;
create policy "Users can insert their own daily activity"
  on public.daily_active_users
  for insert
  with check (auth.uid() = user_id and activity_date between current_date - 1 and current_date + 1);

drop policy if exists "Users can update their own daily activity" on public.daily_active_users;
create policy "Users can update their own daily activity"
  on public.daily_active_users
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id and activity_date between current_date - 1 and current_date + 1);
