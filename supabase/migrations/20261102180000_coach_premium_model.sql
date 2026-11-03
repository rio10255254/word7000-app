-- The speaking coach answers with a stronger model (it catches mistakes the
-- quick one misses) for a learner's first answers each day; after that the
-- quick model takes over, so one heavy day can't cost more than a month's
-- subscription. This counts those answers per learner per UTC day.

create table if not exists word7000_private.ai_coach_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null,
  requests integer not null default 0,
  primary key (user_id, usage_date)
);

revoke all on word7000_private.ai_coach_usage from public, anon, authenticated;

-- Counts one more coach answer for today and returns how many there have been.
create or replace function public.consume_coach_answer_for(p_user uuid)
returns integer
language plpgsql
security definer
set search_path = word7000_private, pg_catalog
as $$
declare
  today date := (timezone('utc', now()))::date;
  used integer;
begin
  if p_user is null then
    raise exception 'user required' using errcode = '22004';
  end if;
  insert into word7000_private.ai_coach_usage as usage (user_id, usage_date, requests)
  values (p_user, today, 1)
  on conflict (user_id, usage_date) do update set requests = usage.requests + 1
  returning usage.requests into used;
  delete from word7000_private.ai_coach_usage where user_id = p_user and usage_date < today - 7;
  return used;
end;
$$;

revoke all on function public.consume_coach_answer_for(uuid) from public, anon, authenticated;
grant execute on function public.consume_coach_answer_for(uuid) to service_role;
