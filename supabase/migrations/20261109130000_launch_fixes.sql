-- Backend fixes before launch. Add-only: every older function keeps its name,
-- arguments and meaning, so a function deployed before this migration (or an
-- older app) keeps working; the new edge functions call the new ones.
--
-- 1. Plus refunds are matched to the refunded transaction, not to the whole
--    subscription: one refund no longer ends every later renewal.
-- 2. Plus stays on during Apple's billing grace period.
-- 3. A failed AI answer gives the learner's request back (a bounded number a
--    day); the site-wide daily total still counts it.
-- 4. With several phones on one account, a phone is not reminded of a streak
--    or a daily goal the learner already kept on another phone, and a phone
--    the learner stopped using stops getting reminders.
-- Intentionally contains no transaction control: the migration runner may
-- wrap this entire migration in its own transaction.

-- 1. Refunds ------------------------------------------------------------------
-- Every renewal of a subscription has its own transaction id and the same
-- original transaction id, and a resubscription keeps that original id too.
-- word7000_private.plus_revocations (kept for the old functions) is keyed by
-- the original id alone, so one refunded month refused every later month the
-- learner paid for. A refund now names the refunded transaction and the end of
-- the period it paid for.

create table if not exists word7000_private.plus_refunds (
  transaction_id text primary key check (transaction_id ~ '^[0-9]{1,32}$'),
  original_transaction_id text not null check (original_transaction_id ~ '^[0-9]{1,32}$'),
  -- The end of the refunded period; null when Apple did not say.
  expires_at timestamptz,
  notification_type text not null,
  revoked_at timestamptz not null default now()
);

create index if not exists plus_refunds_original_idx on word7000_private.plus_refunds (original_transaction_id);

revoke all on word7000_private.plus_refunds from public, anon, authenticated;

-- 2. Billing grace period ---------------------------------------------------------
-- During a billing grace period the app still holds (and sends) the last
-- transaction, whose expiry has passed. Apple's notices carry the renewal info
-- with gracePeriodExpiresDate; the latest one per subscription is kept here.

create table if not exists word7000_private.plus_grace_periods (
  original_transaction_id text primary key check (original_transaction_id ~ '^[0-9]{1,32}$'),
  grace_until timestamptz,
  -- When Apple signed the renewal info: notices can arrive out of order.
  signed_at timestamptz not null,
  updated_at timestamptz not null default now()
);

revoke all on word7000_private.plus_grace_periods from public, anon, authenticated;

-- The three-accounts-a-month rule of claim_plus_for, without its refund check.
create or replace function word7000_private.claim_plus_seat(p_user uuid, p_original_transaction_id text)
returns boolean
language plpgsql
security definer
set search_path = word7000_private, pg_catalog
as $$
declare
  others integer;
begin
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

revoke all on function word7000_private.claim_plus_seat(uuid, text) from public, anon, authenticated, service_role;

-- True when this signed transaction may stand for this account:
-- * it has not expired, or it expired within the last 60 days and Apple says
--   the subscription is in its billing grace period;
-- * it is not a refunded or revoked transaction, and (for a refund) not one
--   for a period that ended no later than the refunded one: a renewal or
--   resubscription after a refund is a new purchase and counts;
-- * a refund recorded before this migration (subscription-wide, no
--   transaction) refuses only transactions bought before Apple reported it;
-- * the subscription is used by at most three accounts a month.
create or replace function public.claim_plus_subscription(
  p_user uuid, p_original_transaction_id text, p_transaction_id text,
  p_expires_at timestamptz, p_purchased_at timestamptz)
returns boolean
language plpgsql
security definer
set search_path = word7000_private, pg_catalog
as $$
begin
  if p_user is null or p_original_transaction_id is null or p_original_transaction_id !~ '^[0-9]{1,32}$'
     or p_transaction_id is null or p_transaction_id !~ '^[0-9]{1,32}$' or p_expires_at is null then
    return false;
  end if;
  if p_expires_at <= now() then
    if p_expires_at < now() - interval '60 days' then
      return false;
    end if;
    if not exists (select 1 from word7000_private.plus_grace_periods
                   where original_transaction_id = p_original_transaction_id and grace_until > now()) then
      return false;
    end if;
  end if;
  if exists (select 1 from word7000_private.plus_refunds as refunds
             where refunds.original_transaction_id = p_original_transaction_id
               and (refunds.transaction_id = p_transaction_id
                    -- A Family Sharing revocation (REVOKE) is about one family
                    -- member's own transaction only.
                    or (refunds.notification_type <> 'REVOKE' and refunds.expires_at is not null
                        and p_expires_at <= refunds.expires_at))) then
    return false;
  end if;
  if exists (select 1 from word7000_private.plus_revocations as legacy
             where legacy.original_transaction_id = p_original_transaction_id
               and (p_purchased_at is null or p_purchased_at <= legacy.revoked_at)) then
    return false;
  end if;
  return word7000_private.claim_plus_seat(p_user, p_original_transaction_id);
end;
$$;

revoke all on function public.claim_plus_subscription(uuid, text, text, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.claim_plus_subscription(uuid, text, text, timestamptz, timestamptz) to service_role;

-- A refund or revocation (p_revoked) or a reversed refund, for one transaction.
create or replace function public.record_plus_refund(
  p_original_transaction_id text, p_transaction_id text, p_expires_at timestamptz, p_type text, p_revoked boolean)
returns void
language plpgsql
security definer
set search_path = word7000_private, pg_catalog
as $$
begin
  if p_original_transaction_id is null or p_original_transaction_id !~ '^[0-9]{1,32}$'
     or p_transaction_id is null or p_transaction_id !~ '^[0-9]{1,32}$' or p_revoked is null then
    return;
  end if;
  if p_revoked then
    insert into word7000_private.plus_refunds (transaction_id, original_transaction_id, expires_at, notification_type)
    values (p_transaction_id, p_original_transaction_id, p_expires_at, left(coalesce(p_type, ''), 40))
    on conflict (transaction_id) do update
      set expires_at = excluded.expires_at, notification_type = excluded.notification_type, revoked_at = now();
  else
    delete from word7000_private.plus_refunds where transaction_id = p_transaction_id;
    -- What the old record_plus_notice did for a reversed refund.
    delete from word7000_private.plus_revocations where original_transaction_id = p_original_transaction_id;
  end if;
end;
$$;

revoke all on function public.record_plus_refund(text, text, timestamptz, text, boolean) from public, anon, authenticated;
grant execute on function public.record_plus_refund(text, text, timestamptz, text, boolean) to service_role;

-- The latest renewal info Apple sent for a subscription: its grace period end,
-- or null when it is not in one. An older notice never replaces a newer one.
create or replace function public.record_plus_renewal(
  p_original_transaction_id text, p_grace_until timestamptz, p_signed_at timestamptz)
returns void
language plpgsql
security definer
set search_path = word7000_private, pg_catalog
as $$
begin
  if p_original_transaction_id is null or p_original_transaction_id !~ '^[0-9]{1,32}$' or p_signed_at is null then
    return;
  end if;
  insert into word7000_private.plus_grace_periods as grace (original_transaction_id, grace_until, signed_at)
  values (p_original_transaction_id, p_grace_until, p_signed_at)
  on conflict (original_transaction_id) do update
    set grace_until = excluded.grace_until, signed_at = excluded.signed_at, updated_at = now()
    where grace.signed_at <= excluded.signed_at;
end;
$$;

revoke all on function public.record_plus_renewal(text, timestamptz, timestamptz) from public, anon, authenticated;
grant execute on function public.record_plus_renewal(text, timestamptz, timestamptz) to service_role;

-- 3. AI requests that were not answered -------------------------------------------
-- consume_ai_quota_for counts a request before Claude is asked, so a burst
-- cannot outrun the limit. When no answer comes back (Claude busy, down, timed
-- out, or its reply unusable) the edge function gives the request back. At
-- most 20 a day, so failures a learner could provoke cannot become unlimited
-- free requests; the site-wide total in ai_daily_totals is never given back.

alter table word7000_private.ai_usage add column if not exists refunds integer not null default 0;

create or replace function public.refund_ai_quota_for(p_user uuid, p_usage_date date)
returns integer
language sql
security definer
set search_path = word7000_private, pg_catalog
as $$
  update word7000_private.ai_usage
  set requests = requests - 1, refunds = refunds + 1
  where user_id = p_user and usage_date = p_usage_date and requests > 0 and refunds < 20
  returning requests;
$$;

revoke all on function public.refund_ai_quota_for(uuid, date) from public, anon, authenticated;
grant execute on function public.refund_ai_quota_for(uuid, date) to service_role;

-- 4. Reminders for an account with several phones ---------------------------------
-- Each phone registers its own copy of the learner's streak and daily
-- progress, and only when the app runs on it. So a phone left in a drawer kept
-- the streak and goal it last saw: it was reminded that a streak was about to
-- end, or that today's goal was not done, after the learner had studied on
-- another phone, and an old phone kept getting reminders for good.
-- Both claims now also skip a phone when
-- * another phone of the same account has a later streak deadline (the
--   learner studied there after this phone last reported) - streak card;
-- * another phone of the same account already reached today's goal - noon;
-- * this phone has not reported for 14 days while another phone of the same
--   account has (a learner with one phone keeps getting reminders).
-- Everything else is exactly as in 20261022120000.

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
    select devices.user_id, devices.device_id
    from latest_devices as devices
    where devices.token_priority = 1
      and devices.enabled = true
      and devices.streak > 0
      and devices.streak_expires_at > now()
      and devices.streak_expires_at <= now() + interval '1 hour'
      and devices.activity_started_for_expires_at is distinct from devices.streak_expires_at
      and not exists (
        select 1 from public.live_activity_devices as other
        where other.user_id = devices.user_id and other.device_id <> devices.device_id
          and other.streak_expires_at > devices.streak_expires_at)
      and not (devices.registration_updated_at < now() - interval '14 days'
        and exists (
          select 1 from public.live_activity_devices as other
          where other.user_id = devices.user_id and other.device_id <> devices.device_id
            and other.registration_updated_at >= now() - interval '14 days'))
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
      and not exists (
        select 1 from public.live_activity_devices as other
        where other.user_id = devices.user_id and other.device_id <> devices.device_id
          and other.progress_date = clock.local_now::date
          and other.studied_today >= other.daily_target)
      and not (devices.registration_updated_at < now() - interval '14 days'
        and exists (
          select 1 from public.live_activity_devices as other
          where other.user_id = devices.user_id and other.device_id <> devices.device_id
            and other.registration_updated_at >= now() - interval '14 days'))
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
