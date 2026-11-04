import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

// Checks the usage statistics migration on PGlite:
// node scripts/test-usage-migration.mjs path/to/@electric-sql/pglite/dist/index.js
const runtime = process.argv[2];
if (!runtime) throw new Error('Pass the path to @electric-sql/pglite/dist/index.js');
const { PGlite } = await import(pathToFileURL(runtime).href);
const db = new PGlite();
const me = '00000000-0000-0000-0000-000000000001';
const guest = '00000000-0000-0000-0000-000000000002';
await db.exec(`
  create role anon; create role authenticated; create role service_role;
  create schema auth;
  create table auth.users (id uuid primary key, is_anonymous boolean default false, created_at timestamptz default now(), deleted_at timestamptz);
  create table caller (id uuid);
  insert into caller values (null);
  create function auth.uid() returns uuid language sql as $$ select id from caller $$;
  create schema word7000_private;
  create table word7000_private.ai_usage (user_id uuid not null references auth.users(id) on delete cascade, usage_date date not null, requests integer not null default 0, primary key (user_id, usage_date));
  create table word7000_private.plus_claims (original_transaction_id text not null, user_id uuid not null references auth.users(id) on delete cascade, last_used timestamptz not null default now(), primary key (original_transaction_id, user_id));
  create table word7000_private.plus_revocations (original_transaction_id text primary key, notification_type text not null, revoked_at timestamptz not null default now());
  create table public.daily_active_users (user_id uuid not null references auth.users(id) on delete cascade, activity_date date not null, primary key (user_id, activity_date));
  insert into auth.users (id, created_at) values ('${me}', now() - interval '8 days');
  insert into auth.users (id, is_anonymous) values ('${guest}', true);
  insert into public.daily_active_users values ('${me}', current_date - 8), ('${me}', current_date - 7), ('${me}', current_date), ('${guest}', current_date);
  insert into word7000_private.ai_usage values ('${me}', current_date, 12);
  insert into word7000_private.plus_claims (original_transaction_id, user_id) values ('t1', '${me}');
`);
await db.exec(await fs.readFile('supabase/migrations/20261104120000_usage_events.sql', 'utf8'));
const one = async (sql, args = []) => (await db.query(sql, args)).rows[0];

await assert.rejects(db.query(`select public.log_usage('[]'::jsonb)`), /sign in required/);
await db.query(`update caller set id = $1`, [me]);
const today = (await one(`select current_date::text as d`)).d;
const batch = [
  { day: today, event: 'speaking', detail: 'completed', count: 2 },
  { day: today, event: 'speaking', detail: 'completed', count: 1 },
  { day: today, event: 'study_session', detail: 'core:1,2', count: 1 },
  { day: today, event: 'Bad Event', detail: '', count: 1 },
  { day: today, event: 'paywall_view', detail: 'has spaces', count: 1 },
  { day: '2020-01-01', event: 'speaking', detail: '', count: 1 },
  { day: 'nope', event: 'speaking', detail: '', count: 1 },
  { day: today, event: 'speaking', detail: 'skipped', count: -3 },
  'not an object',
];
assert.equal((await one(`select public.log_usage($1::jsonb) as n`, [JSON.stringify(batch)])).n, 2);
await db.query(`select public.log_usage($1::jsonb)`, [JSON.stringify([{ day: today, event: 'speaking', detail: 'completed', count: 4 }])]);
assert.equal((await one(`select count from word7000_private.usage_events where event = 'speaking'`)).count, 7);
await assert.rejects(db.query(`select public.log_usage('{}'::jsonb)`), /invalid events/);

await db.query(`update caller set id = $1`, [guest]);
await db.query(`select public.log_usage($1::jsonb)`, [JSON.stringify([{ day: today, event: 'speaking', detail: 'completed', count: 1 }])]);

const report = (await one(`select public.usage_report(7) as r`)).r;
assert.equal(report.users.total, 2);
assert.equal(report.users.guests, 1);
assert.equal(report.users.subscribers, 1);
assert.equal(report.active.today, 2);
assert.equal(report.retention.d1.cohort, 1);
assert.equal(report.retention.d1.back, 1);
assert.equal(report.retention.d7.back, 1);
assert.equal(report.daily.length, 7);
const speaking = report.events.find((e) => e.event === 'speaking' && e.detail === 'completed');
assert.equal(speaking.users, 2);
assert.equal(speaking.total, 8);
assert.equal(report.event_users.speaking, 2);
assert.equal(report.ai_per_day['11-20'], 1);

// Deleting the account deletes its counts.
await db.query(`delete from auth.users where id = $1`, [guest]);
assert.equal((await one(`select count(*)::int as n from word7000_private.usage_events where user_id = $1`, [guest])).n, 0);
console.log('usage migration ok');
