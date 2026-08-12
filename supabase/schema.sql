create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  progress jsonb not null default '{}'::jsonb,
  custom_sets jsonb not null default '{"sets":[],"customWords":[]}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.profiles
  add column if not exists progress jsonb not null default '{}'::jsonb,
  add column if not exists custom_sets jsonb not null default '{"sets":[],"customWords":[]}'::jsonb;

alter table public.profiles
  add column if not exists updated_at timestamptz not null default now();

create index if not exists profiles_updated_at_idx
  on public.profiles (updated_at desc);

create table if not exists public.daily_active_users (
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_date date not null default current_date,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  primary key (user_id, activity_date)
);

create index if not exists daily_active_users_activity_date_idx
  on public.daily_active_users (activity_date desc);

create index if not exists daily_active_users_last_seen_at_idx
  on public.daily_active_users (last_seen_at desc);

create table if not exists public.live_activity_devices (
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  push_to_start_token text not null,
  activity_push_token text,
  enabled boolean not null default true,
  app_locale text not null default 'zh-TW' check (app_locale in ('zh-TW', 'en')),
  time_zone text not null default 'Asia/Taipei',
  streak integer not null default 0 check (streak >= 0),
  streak_expires_at timestamptz,
  activity_started_for_expires_at timestamptz,
  last_push_error text,
  updated_at timestamptz not null default now(),
  primary key (user_id, device_id)
);

create index if not exists live_activity_devices_due_idx
  on public.live_activity_devices (streak_expires_at)
  where enabled = true and streak_expires_at is not null;

create or replace function public.claim_due_streak_live_activities()
returns setof public.live_activity_devices
language sql
security definer
set search_path = public
as $$
  update public.live_activity_devices
  set
    activity_started_for_expires_at = streak_expires_at,
    last_push_error = null,
    updated_at = now()
  where enabled = true
    and streak > 0
    and streak_expires_at > now()
    and streak_expires_at <= now() + interval '1 hour'
    and activity_started_for_expires_at is distinct from streak_expires_at
  returning *;
$$;

revoke all on function public.claim_due_streak_live_activities() from public, anon, authenticated;
grant execute on function public.claim_due_streak_live_activities() to service_role;

alter table public.profiles enable row level security;
alter table public.daily_active_users enable row level security;
alter table public.live_activity_devices enable row level security;

drop policy if exists "Users can read their own profile" on public.profiles;
create policy "Users can read their own profile"
  on public.profiles
  for select
  using (auth.uid() = id);

drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile"
  on public.profiles
  for insert
  with check (auth.uid() = id);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles
  for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "Users can delete their own profile" on public.profiles;
create policy "Users can delete their own profile"
  on public.profiles
  for delete
  using (auth.uid() = id);

drop policy if exists "Users can read their own daily activity" on public.daily_active_users;
create policy "Users can read their own daily activity"
  on public.daily_active_users
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own daily activity" on public.daily_active_users;
create policy "Users can insert their own daily activity"
  on public.daily_active_users
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own daily activity" on public.daily_active_users;
create policy "Users can update their own daily activity"
  on public.daily_active_users
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own daily activity" on public.daily_active_users;
create policy "Users can delete their own daily activity"
  on public.daily_active_users
  for delete
  using (auth.uid() = user_id);

drop policy if exists "Users can read their own live activity devices" on public.live_activity_devices;
create policy "Users can read their own live activity devices"
  on public.live_activity_devices
  for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their own live activity devices" on public.live_activity_devices;
create policy "Users can insert their own live activity devices"
  on public.live_activity_devices
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own live activity devices" on public.live_activity_devices;
create policy "Users can update their own live activity devices"
  on public.live_activity_devices
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own live activity devices" on public.live_activity_devices;
create policy "Users can delete their own live activity devices"
  on public.live_activity_devices
  for delete
  using (auth.uid() = user_id);
