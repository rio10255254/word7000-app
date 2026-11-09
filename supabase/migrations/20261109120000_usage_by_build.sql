-- Usage per app build: the same counts as usage_report(), split by the build
-- each account runs now (app_installs, the latest version the app reported).
-- Counts are not stamped with a build when they are made, so an account's
-- whole span is put under the build it has today: good enough to compare the
-- two TestFlight lines, which testers rarely switch between. Accounts that
-- never reported a version show as build "?". Read-only, service role only,
-- shown by the "📈 使用數據" workflow.

create or replace function public.usage_by_build(p_days integer default 7)
returns jsonb
language sql
stable
security definer
set search_path = word7000_private, public, pg_catalog
as $$
  with span as (
    select (now() at time zone 'Asia/Taipei')::date - (greatest(1, least(coalesce(p_days, 7), 90)) - 1) as since
  ), counted as (
    select e.user_id, e.event, e.detail, e.count
    from word7000_private.usage_events e, span
    where e.day >= span.since
  ), active as (
    select distinct a.user_id
    from public.daily_active_users a, span
    where a.activity_date >= span.since
  ), builds as (
    select coalesce(i.app_version, '?') as app_version, i.app_build, x.user_id
    from active x
    left join word7000_private.app_installs i on i.user_id = x.user_id
  ), people as (
    select app_version, app_build, count(*) as accounts
    from builds
    group by app_version, app_build
  ), events as (
    select coalesce(i.app_version, '?') as app_version, i.app_build, c.event, c.detail,
           count(distinct c.user_id) as people, sum(c.count) as times
    from counted c
    left join word7000_private.app_installs i on i.user_id = c.user_id
    group by 1, 2, 3, 4
  )
  select jsonb_build_object(
    'builds', coalesce((select jsonb_agg(jsonb_build_object('app_version', app_version, 'app_build', app_build, 'accounts', accounts)
                                         order by app_version desc, app_build desc nulls last) from people), '[]'::jsonb),
    'events', coalesce((select jsonb_agg(jsonb_build_object('app_version', app_version, 'app_build', app_build, 'event', event,
                                                            'detail', detail, 'people', people, 'times', times)
                                         order by app_version desc, app_build desc nulls last, event, detail) from events), '[]'::jsonb)
  );
$$;

revoke all on function public.usage_by_build(integer) from public, anon, authenticated;
grant execute on function public.usage_by_build(integer) to service_role;
