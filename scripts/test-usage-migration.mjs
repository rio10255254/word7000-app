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
  insert into auth.users (id, is_anonymous, created_at) values
    ('00000000-0000-0000-0000-000000000003', true, now() - interval '20 days'),
    ('00000000-0000-0000-0000-000000000004', true, now() - interval '2 days');
  insert into public.daily_active_users values ('00000000-0000-0000-0000-000000000003', current_date - 20);
  insert into word7000_private.ai_usage values ('${me}', current_date, 12);
  insert into word7000_private.plus_claims (original_transaction_id, user_id) values ('t1', '${me}');
`);
await db.exec(await fs.readFile('supabase/migrations/20261104120000_usage_events.sql', 'utf8'));
await db.exec(await fs.readFile('supabase/migrations/20261104140000_usage_report_by_account_type.sql', 'utf8'));
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

// The second guest moved into an Apple account; only its own session can retire it.
await db.query(`update caller set id = '00000000-0000-0000-0000-000000000004'`);
await db.query(`select public.retire_guest()`);
await db.query(`update caller set id = $1`, [me]);
await db.query(`select public.retire_guest()`); // an Apple account is never retired
assert.equal((await one(`select count(*)::int as n from word7000_private.retired_guests`)).n, 1);
const report = (await one(`select public.usage_report(7) as r`)).r;
assert.equal(report.users.total, 2, 'the empty old guest and the merged guest are left out');
assert.equal(report.users.guests, 1);
assert.equal(report.users.apple, 1);
assert.equal(report.users.left_out_merged, 1);
assert.equal(report.users.left_out_empty, 1);
assert.equal(report.active.today_apple, 1);
assert.equal(report.time_zone, 'Asia/Taipei');
assert.equal(report.users.subscribers, 1);
assert.equal(report.active.today, 2);
assert.equal(report.retention.apple.d1.cohort, 1);
assert.equal(report.retention.apple.d1.back, 1);
assert.equal(report.retention.apple.d7.back, 1);
assert.equal(report.retention.guests.d7.cohort, 1, 'retention still counts the guest that tried once and left');
assert.equal(report.retention.guests.d7.back, 0);
assert.equal(report.daily.length, 7);
const speaking = report.events.find((e) => e.event === 'speaking' && e.detail === 'completed');
assert.equal(speaking.users, 2);
assert.equal(speaking.total, 8);
assert.equal(report.event_users.speaking, 2);
assert.equal(report.ai_per_day['11-20'], 1);

// Per build: each account under the build it runs now; one that never
// reported a version under "?". Only the service role may read it.
await db.exec(`
  create table word7000_private.app_installs (user_id uuid primary key references auth.users(id) on delete cascade,
    app_version text not null, app_build integer, os_version text, language text not null default 'zh', last_seen timestamptz not null default now());
  insert into word7000_private.app_installs (user_id, app_version, app_build) values ('${me}', '2.0.2', 23);
`);
await db.exec(await fs.readFile('supabase/migrations/20261109120000_usage_by_build.sql', 'utf8'));
const perBuild = (await one(`select public.usage_by_build(7) as r`)).r;
const mine = perBuild.builds.find((b) => b.app_build === 23);
assert.equal(mine.accounts, 1);
assert.equal(perBuild.builds.find((b) => b.app_version === '?').accounts, 1, 'the guest never reported a version');
const mySpeaking = perBuild.events.find((e) => e.app_build === 23 && e.event === 'speaking' && e.detail === 'completed');
assert.ok(mySpeaking && mySpeaking.people === 1, 'my speaking is under my build');
assert.equal(perBuild.events.filter((e) => e.event === 'speaking' && e.detail === 'completed').reduce((n, e) => n + e.times, 0), 8,
  'every count lands under some build');
assert.equal((await one(`select has_function_privilege('authenticated', 'public.usage_by_build(integer)', 'execute') as ok`)).ok, false);

// Deleting the account deletes its counts.
await db.query(`delete from auth.users where id = $1`, [guest]);
assert.equal((await one(`select count(*)::int as n from word7000_private.usage_events where user_id = $1`, [guest])).n, 0);
console.log('usage migration ok');
