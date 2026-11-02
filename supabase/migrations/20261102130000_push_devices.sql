-- Push notifications for the developer's messages to everyone.
--
-- An announcement can ask to be pushed as well as shown in the app; the
-- broadcast-push function sends it once (pushed_at), so calling it again,
-- or by anyone, cannot send anything new.

alter table public.announcements add column if not exists push boolean not null default false;
alter table public.announcements add column if not exists pushed_at timestamptz;

-- One row per iPhone that allowed notifications. Written only through
-- register_push_device, which ties the token to whoever is signed in now.
create table if not exists public.push_devices (
  token text primary key check (token ~ '^[0-9a-f]{32,512}$'),
  user_id uuid not null references auth.users(id) on delete cascade,
  -- Who the learner is, for messages meant for some of them.
  audience text not null default 'guest' check (audience in ('guest', 'free', 'plus')),
  language text not null default 'zh' check (language in ('zh', 'en')),
  updated_at timestamptz not null default now()
);

alter table public.push_devices enable row level security;
revoke all on public.push_devices from anon, authenticated;

create or replace function public.register_push_device(p_token text, p_audience text, p_language text)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'sign in required' using errcode = '42501';
  end if;
  insert into public.push_devices (token, user_id, audience, language, updated_at)
  values (lower(p_token), me, p_audience, p_language, now())
  on conflict (token) do update
    set user_id = excluded.user_id, audience = excluded.audience,
        language = excluded.language, updated_at = now();
  -- A learner's few phones, not a script's thousands of tokens.
  delete from public.push_devices
  where user_id = me
    and token not in (
      select token from public.push_devices where user_id = me order by updated_at desc limit 5
    );
end;
$$;

revoke all on function public.register_push_device(text, text, text) from public, anon;
grant execute on function public.register_push_device(text, text, text) to authenticated;
