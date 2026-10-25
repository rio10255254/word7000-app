-- When each learner first used the online AI. The first 7 days from then get
-- the Plus-level AI as a trial; the date is set once here and cannot be moved
-- by the app.

create table if not exists word7000_private.ai_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  first_seen timestamptz not null default now()
);

revoke all on word7000_private.ai_members from public, anon, authenticated;

create or replace function public.consume_ai_quota()
returns jsonb
language plpgsql
security definer
set search_path = word7000_private, pg_catalog
as $$
declare
  caller uuid := auth.uid();
  used integer;
  started timestamptz;
begin
  if caller is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  insert into word7000_private.ai_members (user_id) values (caller)
  on conflict (user_id) do nothing;
  select first_seen into started from word7000_private.ai_members where user_id = caller;

  insert into word7000_private.ai_usage as usage (user_id, usage_date, requests)
  values (caller, (timezone('utc', now()))::date, 1)
  on conflict (user_id, usage_date) do update set requests = usage.requests + 1
  returning usage.requests into used;
  delete from word7000_private.ai_usage
  where user_id = caller and usage_date < (timezone('utc', now()))::date - 7;

  return jsonb_build_object('requests', used, 'first_seen', started);
end;
$$;

revoke all on function public.consume_ai_quota() from public, anon;
grant execute on function public.consume_ai_quota() to authenticated;
