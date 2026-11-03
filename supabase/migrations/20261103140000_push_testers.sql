-- Test phones: the developer marks their own iPhone as a test phone from the
-- app (long press on the push status row), and a message for "tester" goes
-- only to those phones, in the app and as a push, so testing announcements
-- never reaches everyone else.

alter table public.push_devices add column if not exists tester boolean not null default false;

alter table public.announcements drop constraint if exists announcements_audience_check;
alter table public.announcements add constraint announcements_audience_check
  check (audience in ('all', 'guest', 'free', 'plus', 'tester'));

-- Only the account that registered a token can mark it.
create or replace function public.set_push_tester(p_token text, p_tester boolean)
returns boolean
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  me uuid := auth.uid();
  changed integer;
begin
  if me is null then
    raise exception 'sign in required' using errcode = '42501';
  end if;
  update public.push_devices set tester = coalesce(p_tester, false), updated_at = now()
  where token = lower(p_token) and user_id = me;
  get diagnostics changed = row_count;
  return changed > 0;
end;
$$;

revoke all on function public.set_push_tester(text, boolean) from public, anon;
grant execute on function public.set_push_tester(text, boolean) to authenticated;
