-- The usage report, closer to real people:
-- * days are Taiwan days (the learners' and the developer's), not UTC days;
-- * every count is split into Apple accounts and guests;
-- * guests that are not separate people are left out of the counts: a guest
--   whose progress moved into an Apple account that already existed
--   (retired by the app, see retire_guest) and an empty guest, one that
--   joined more than 7 days ago and was only ever active on its first day
--   with no usage counted. Nothing is deleted; the report says how many
--   were left out. Guest retention still counts every guest, so people who
--   tried the app once and left show up there as not returning.

create table if not exists word7000_private.retired_guests (
  user_id uuid primary key references auth.users(id) on delete cascade,
  retired_at timestamptz not null default now()
);

revoke all on word7000_private.retired_guests from public, anon, authenticated;

-- Called by the app with the guest's own session, just before it signs into
-- an Apple account that already has the learner's data.
create or replace function public.retire_guest()
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
  if exists (select 1 from auth.users where id = me and coalesce(is_anonymous, false)) then
    insert into word7000_private.retired_guests (user_id) values (me) on conflict do nothing;
  end if;
end;
$$;

revoke all on function public.retire_guest() from public, anon;
grant execute on function public.retire_guest() to authenticated;

create or replace function public.usage_report(p_days integer default 7)
returns jsonb
language sql
stable
security definer
set search_path = word7000_private, public, pg_catalog
as $$
  with params as (
    select greatest(1, least(coalesce(p_days, 7), 90)) as days,
           (now() at time zone 'Asia/Taipei')::date as today
  ), span as (
    select days, today, today - (days - 1) as since from params
  ), activity as (
    select user_id, activity_date from public.daily_active_users
  ), everyone as (
    select u.id, coalesce(u.is_anonymous, false) as guest,
           (u.created_at at time zone 'Asia/Taipei')::date as joined,
           exists (select 1 from word7000_private.retired_guests r where r.user_id = u.id) as retired,
           (select count(distinct a.activity_date) from activity a where a.user_id = u.id) as active_days,
           exists (select 1 from word7000_private.usage_events e where e.user_id = u.id) as counted
    from auth.users u
    where u.deleted_at is null
  ), people as (
    -- Who counts as a person in this report.
    select id, guest, joined, false as left_out from everyone where not guest
    union all
    select id, guest, joined,
           retired or (joined < (select today from span) - 7 and active_days <= 1 and not counted)
    from everyone where guest
  ), counted_people as (
    select * from people where not left_out
  ), subscribers as (
    select count(distinct c.user_id) as n
    from word7000_private.plus_claims c
    left join word7000_private.plus_revocations r using (original_transaction_id)
    where r.original_transaction_id is null and c.last_used > now() - interval '35 days'
  ), events as (
    select e.* from word7000_private.usage_events e, span where e.day >= span.since
  ), active_people as (
    select a.user_id, a.activity_date, p.guest
    from activity a join counted_people p on p.id = a.user_id
  )
  select jsonb_build_object(
    'days', (select days from span),
    'since', (select since from span),
    'today', (select today from span),
    'time_zone', 'Asia/Taipei',
    'users', (select jsonb_build_object(
        'total', count(*),
        'apple', count(*) filter (where not guest),
        'guests', count(*) filter (where guest),
        'new', count(*) filter (where joined >= (select since from span)),
        'new_apple', count(*) filter (where joined >= (select since from span) and not guest),
        'new_guests', count(*) filter (where joined >= (select since from span) and guest),
        'subscribers', (select n from subscribers),
        'left_out_merged', (select count(*) from everyone where guest and retired),
        'left_out_empty', (select count(*) from people where guest and left_out) - (select count(*) from everyone where guest and retired))
      from counted_people),
    'active', (select jsonb_build_object(
        'today', count(distinct user_id) filter (where activity_date = s.today),
        'today_apple', count(distinct user_id) filter (where activity_date = s.today and not guest),
        'yesterday', count(distinct user_id) filter (where activity_date = s.today - 1),
        'yesterday_apple', count(distinct user_id) filter (where activity_date = s.today - 1 and not guest),
        'last_7_days', count(distinct user_id) filter (where activity_date > s.today - 7),
        'last_7_days_apple', count(distinct user_id) filter (where activity_date > s.today - 7 and not guest),
        'last_30_days', count(distinct user_id) filter (where activity_date > s.today - 30),
        'last_30_days_apple', count(distinct user_id) filter (where activity_date > s.today - 30 and not guest))
      from active_people, span s),
    'daily', coalesce((
      select jsonb_agg(jsonb_build_object('day', d, 'active', a, 'active_apple', aa, 'new', n, 'new_apple', na) order by d)
      from (
        select g::date as d,
               (select count(distinct user_id) from active_people where activity_date = g::date) as a,
               (select count(distinct user_id) from active_people where activity_date = g::date and not guest) as aa,
               (select count(*) from counted_people where joined = g::date) as n,
               (select count(*) from counted_people where joined = g::date and not guest) as na
        from span, generate_series(span.since, span.today, interval '1 day') as g
      ) as days), '[]'::jsonb),
    'retention', (
      select jsonb_object_agg(kind, numbers)
      from (
        select kind, jsonb_build_object(
          'd1', jsonb_build_object('cohort', count(*) filter (where p.joined <= s.today - 1),
                'back', count(*) filter (where p.joined <= s.today - 1 and exists (select 1 from activity a where a.user_id = p.id and a.activity_date = p.joined + 1))),
          'd7', jsonb_build_object('cohort', count(*) filter (where p.joined <= s.today - 7),
                'back', count(*) filter (where p.joined <= s.today - 7 and exists (select 1 from activity a where a.user_id = p.id and a.activity_date between p.joined + 7 and p.joined + 13))),
          'd30', jsonb_build_object('cohort', count(*) filter (where p.joined <= s.today - 30),
                'back', count(*) filter (where p.joined <= s.today - 30 and exists (select 1 from activity a where a.user_id = p.id and a.activity_date between p.joined + 30 and p.joined + 36)))) as numbers
        from (
          -- Retention counts every guest except the ones merged into an Apple account.
          select e.id, e.joined, case when e.guest then 'guests' else 'apple' end as kind
          from everyone e where not e.retired
        ) as p, span s
        where p.joined > s.today - 90
        group by kind
      ) as by_kind),
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
        from word7000_private.ai_usage, span where usage_date >= span.since
        group by 1
      ) as buckets), '{}'::jsonb)
  );
$$;

revoke all on function public.usage_report(integer) from public, anon, authenticated;
grant execute on function public.usage_report(integer) to service_role;
