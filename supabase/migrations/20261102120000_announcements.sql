-- Messages from the developer to everyone using the app: the app reads the
-- live ones and shows each once. Written only with the service role (the
-- "Broadcast a message" workflow, or the Supabase dashboard); anyone may
-- read what is live.

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  -- Who sees it: everyone, guests, signed in without Plus, or Plus.
  audience text not null default 'all' check (audience in ('all', 'guest', 'free', 'plus')),
  title_zh text not null default '' check (char_length(title_zh) <= 80),
  body_zh text not null default '' check (char_length(body_zh) <= 600),
  title_en text not null default '' check (char_length(title_en) <= 80),
  body_en text not null default '' check (char_length(body_en) <= 600),
  -- An https link, or "plus" to open the Plus offer.
  link text check (link is null or link = 'plus' or link ~ '^https://'),
  link_label_zh text not null default '' check (char_length(link_label_zh) <= 30),
  link_label_en text not null default '' check (char_length(link_label_en) <= 30),
  active boolean not null default true
);

alter table public.announcements enable row level security;

drop policy if exists "Live announcements are public" on public.announcements;
create policy "Live announcements are public" on public.announcements
  for select to anon, authenticated
  using (active and starts_at <= now() and (ends_at is null or ends_at > now()));

revoke all on public.announcements from anon, authenticated;
grant select on public.announcements to anon, authenticated;
