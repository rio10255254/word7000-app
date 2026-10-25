-- Daily AI request counter, one row per learner per UTC day. The `ai` edge
-- function increments it before each Groq call and refuses requests past its
-- AI_DAILY_LIMIT, so one account cannot spend the shared Groq allowance.

create schema if not exists word7000_private;

create table if not exists word7000_private.ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null default (timezone('utc', now()))::date,
  requests integer not null default 0,
  primary key (user_id, usage_date)
);

revoke all on word7000_private.ai_usage from public, anon, authenticated;

create or replace function public.consume_ai_request()
returns integer
language plpgsql
security definer
set search_path = word7000_private, pg_catalog
as $$
declare
  caller uuid := auth.uid();
  used integer;
begin
  if caller is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  insert into word7000_private.ai_usage as usage (user_id, usage_date, requests)
  values (caller, (timezone('utc', now()))::date, 1)
  on conflict (user_id, usage_date) do update set requests = usage.requests + 1
  returning usage.requests into used;
  -- Old days are only needed for the current limit.
  delete from word7000_private.ai_usage
  where user_id = caller and usage_date < (timezone('utc', now()))::date - 7;
  return used;
end;
$$;

revoke all on function public.consume_ai_request() from public, anon;
grant execute on function public.consume_ai_request() to authenticated;
