-- Word list content published without an app update (see RemoteContent in
-- the app): fixes to the built-in words and official word banks. Everyone
-- can read the live rows; only the service role (the "✏️ 校正單字" and
-- "📚 上架字庫" workflows) writes them.

create table if not exists public.content_corrections (
  mode text not null check (mode in ('english', 'chinese')),
  word_id text not null check (word_id ~ '^[A-Za-z0-9_-]{1,120}$'),
  fields jsonb not null default '{}'::jsonb check (jsonb_typeof(fields) = 'object' and pg_column_size(fields) < 8192),
  hidden boolean not null default false,
  note text check (note is null or char_length(note) <= 300),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (mode, word_id)
);

create table if not exists public.official_banks (
  id text primary key check (id ~ '^[a-z0-9][a-z0-9-]{1,39}$'),
  mode text not null check (mode in ('english', 'chinese')),
  name_zh text not null check (char_length(name_zh) between 1 and 40),
  name_en text not null default '' check (char_length(name_en) <= 60),
  description_zh text not null default '' check (char_length(description_zh) <= 300),
  description_en text not null default '' check (char_length(description_en) <= 400),
  icon text not null default 'books.vertical.fill' check (icon ~ '^[a-z0-9.]{1,60}$'),
  color text not null default '#5856D6' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  premium boolean not null default false,
  sort integer not null default 0,
  words jsonb not null check (jsonb_typeof(words) = 'array' and jsonb_array_length(words) between 1 and 5000),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.content_corrections enable row level security;
alter table public.official_banks enable row level security;

drop policy if exists "Live corrections are public" on public.content_corrections;
create policy "Live corrections are public" on public.content_corrections
  for select to anon, authenticated using (active);

drop policy if exists "Live official banks are public" on public.official_banks;
create policy "Live official banks are public" on public.official_banks
  for select to anon, authenticated using (active);

revoke all on public.content_corrections from anon, authenticated;
revoke all on public.official_banks from anon, authenticated;
grant select on public.content_corrections to anon, authenticated;
grant select on public.official_banks to anon, authenticated;
grant all on public.content_corrections to service_role;
grant all on public.official_banks to service_role;
