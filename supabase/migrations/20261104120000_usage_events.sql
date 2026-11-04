-- Usage statistics: how many times each learner used each feature per day.
-- Only counts: an event name ("speaking") and a short detail ("completed",
-- "core:1,2"), never words, answers, recordings or personal data. Rows go with
-- the account when it is deleted. Read through usage_report() (service role
-- only), shown by the "📈 使用數據" workflow.

create table if not exists word7000_private.usage_events (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  event text not null check (event ~ '^[a-z_]{2,32}$'),
  detail text not null default '' check (detail ~ '^[A-Za-z0-9_.:,-]{0,60}$'),
  count integer not null check (count > 0),
  primary key (user_id, day, event, detail)
);

create index if not exists usage_events_day on word7000_private.usage_events (day);

revoke all on word7000_private.usage_events from public, anon, authenticated;

-- The app sends what it counted since the last send, in one batch:
-- [{"day":"2026-11-04","event":"speaking","detail":"completed","count":3}, ...]
-- Malformed rows are skipped, so one bad row never blocks the rest.
create or replace function public.log_usage(p_events jsonb)
returns integer
language plpgsql
security definer
set search_path = word7000_private, public, pg_catalog
as $$
declare
  me uuid := auth.uid();
  saved integer;
begin
  if me is null then
    raise exception 'sign in required' using errcode = '42501';
  end if;
  if jsonb_typeof(p_events) is distinct from 'array' or jsonb_array_length(p_events) > 200 then
    raise exception 'invalid events' using errcode = '22023';
  end if;
  with raw as (
    select e->>'day' as day_text, e->>'event' as event, coalesce(e->>'detail', '') as detail, e->>'count' as count_text
    from jsonb_array_elements(p_events) as e
    where jsonb_typeof(e) = 'object'
  ), valid as (
    select case when day_text ~ '^\d{4}-\d{2}-\d{2}$' then day_text::date end as day,
           event, detail,
           case when count_text ~ '^\d{1,6}$' then count_text::integer end as count
    from raw
    where event ~ '^[a-z_]{2,32}$' and detail ~ '^[A-Za-z0-9_.:,-]{0,60}$'
  ), batch as (
    select day, event, detail, least(sum(count), 10000)::integer as count
    from valid
    where day between current_date - 14 and current_date + 1 and count > 0
    group by day, event, detail
  )
  insert into word7000_private.usage_events as u (user_id, day, event, detail, count)
  select me, day, event, detail, count from batch
  on conflict (user_id, day, event, detail) do update set count = least(u.count + excluded.count, 100000);
  get diagnostics saved = row_count;
  delete from word7000_private.usage_events where user_id = me and day < current_date - 400;
  return saved;
end;
$$;

revoke all on function public.log_usage(jsonb) from public, anon;
grant execute on function public.log_usage(jsonb) to authenticated;

-- Everything the "📈 使用數據" workflow shows, for the last p_days days.
create or replace function public.usage_report(p_days integer default 7)
returns jsonb
language sql
stable
security definer
set search_path = word7000_private, public, pg_catalog
as $$
  with params as (
    select greatest(1, least(coalesce(p_days, 7), 90)) as days,
           current_date - (greatest(1, least(coalesce(p_days, 7), 90)) - 1) as since
  ), people as (
    select id, is_anonymous, created_at::date as joined from auth.users where deleted_at is null
  ), active as (
    select user_id, activity_date from public.daily_active_users
  ), subscribers as (
    select count(distinct c.user_id) as n
    from word7000_private.plus_claims c
    left join word7000_private.plus_revocations r using (original_transaction_id)
    where r.original_transaction_id is null and c.last_used > now() - interval '35 days'
  ), events as (
    select e.* from word7000_private.usage_events e, params where e.day >= params.since
  )
  select jsonb_build_object(
    'days', (select days from params),
    'since', (select since from params),
    'users', (select jsonb_build_object(
        'total', count(*),
        'apple', count(*) filter (where not coalesce(is_anonymous, false)),
        'guests', count(*) filter (where coalesce(is_anonymous, false)),
        'new', count(*) filter (where joined >= (select since from params)),
        'new_apple', count(*) filter (where joined >= (select since from params) and not coalesce(is_anonymous, false)),
        'subscribers', (select n from subscribers))
      from people),
    'active', jsonb_build_object(
      'today', (select count(distinct user_id) from active where activity_date = current_date),
      'yesterday', (select count(distinct user_id) from active where activity_date = current_date - 1),
      'last_7_days', (select count(distinct user_id) from active where activity_date > current_date - 7),
      'last_30_days', (select count(distinct user_id) from active where activity_date > current_date - 30)),
    'daily', coalesce((
      select jsonb_agg(jsonb_build_object('day', d, 'active', a, 'new', n) order by d)
      from (
        select g::date as d,
               (select count(distinct user_id) from active where activity_date = g::date) as a,
               (select count(*) from people where joined = g::date) as n
        from params, generate_series(params.since, current_date, interval '1 day') as g
      ) as days), '[]'::jsonb),
    'retention', (
      select jsonb_build_object(
        'd1', jsonb_build_object('cohort', count(*) filter (where p.joined <= current_date - 1),
              'back', count(*) filter (where p.joined <= current_date - 1 and exists (select 1 from active a where a.user_id = p.id and a.activity_date = p.joined + 1))),
        'd7', jsonb_build_object('cohort', count(*) filter (where p.joined <= current_date - 7),
              'back', count(*) filter (where p.joined <= current_date - 7 and exists (select 1 from active a where a.user_id = p.id and a.activity_date between p.joined + 7 and p.joined + 13))),
        'd30', jsonb_build_object('cohort', count(*) filter (where p.joined <= current_date - 30),
              'back', count(*) filter (where p.joined <= current_date - 30 and exists (select 1 from active a where a.user_id = p.id and a.activity_date between p.joined + 30 and p.joined + 36))))
      from people p where p.joined > current_date - 90),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object('event', event, 'detail', detail, 'users', users, 'total', total) order by event, total desc)
      from (select event, detail, count(distinct user_id) as users, sum(count) as total from events group by event, detail) as grouped), '[]'::jsonb),
    'event_users', coalesce((
      select jsonb_object_agg(event, users)
      from (select event, count(distinct user_id) as users from events group by event) as grouped), '{}'::jsonb),
    'ai_per_day', coalesce((
      select jsonb_object_agg(bucket, n)
      from (
        select case when requests <= 3 then '1-3' when requests <= 10 then '4-10' when requests <= 20 then '11-20'
                    when requests <= 50 then '21-50' else '51+' end as bucket, count(*) as n
        from word7000_private.ai_usage, params where usage_date >= params.since
        group by 1
      ) as buckets), '{}'::jsonb)
  );
$$;

revoke all on function public.usage_report(integer) from public, anon, authenticated;
grant execute on function public.usage_report(integer) to service_role;
