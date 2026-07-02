create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  progress jsonb not null default '{}'::jsonb,
  custom_sets jsonb not null default '{"sets":[],"customWords":[]}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.profiles
  add column if not exists custom_sets jsonb not null default '{"sets":[],"customWords":[]}'::jsonb;

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

alter table public.profiles enable row level security;
alter table public.daily_active_users enable row level security;

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
