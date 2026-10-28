import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

// Checks the 1.0 security migration on PGlite, a PostgreSQL build that runs in
// Node: node scripts/test-security-migration.mjs path/to/@electric-sql/pglite/dist/index.js
const runtime = process.argv[2];
if (!runtime) throw new Error('Pass the path to @electric-sql/pglite/dist/index.js');
const { PGlite } = await import(pathToFileURL(runtime).href);
const db = new PGlite();
await db.exec(`
  create role anon; create role authenticated; create role service_role;
  create schema auth; create table auth.users (id uuid primary key);
  create function auth.uid() returns uuid language sql as $$ select null::uuid $$;
  create function auth.jwt() returns jsonb language sql as $$ select '{}'::jsonb $$;
  create schema word7000_private;
  create table word7000_private.ai_usage (user_id uuid not null references auth.users(id) on delete cascade, usage_date date not null, requests integer not null default 0, primary key (user_id, usage_date));
  create table word7000_private.ai_members (user_id uuid primary key references auth.users(id) on delete cascade, first_seen timestamptz not null default now());
  create function public.consume_ai_quota() returns jsonb language sql as $$ select '{}'::jsonb $$;
  create function public.consume_ai_request() returns integer language sql as $$ select 1 $$;
  create table public.live_activity_devices (
    user_id uuid not null, device_id text not null, push_to_start_token text not null, activity_push_token text,
    enabled boolean not null default true, time_zone text not null default 'UTC', last_push_error text,
    updated_at timestamptz not null default now(), registration_updated_at timestamptz not null default now(),
    primary key(user_id, device_id));
  create table public.profiles (id uuid primary key, progress jsonb not null default '{}', custom_sets jsonb not null default '{}');
  create table public.daily_active_users (user_id uuid, activity_date date);
  alter table public.daily_active_users enable row level security;
  insert into public.live_activity_devices (user_id, device_id, push_to_start_token) values
    ('00000000-0000-0000-0000-00000000000a', 'old', 'not-a-token');
`);
await db.exec(await fs.readFile('supabase/migrations/20261028120000_ai_and_device_limits.sql', 'utf8'));
const one = async (sql, args = []) => (await db.query(sql, args)).rows[0];
// Bad tokens were disabled before the NOT VALID checks.
assert.equal((await one(`select count(*)::int as n from live_activity_devices where device_id = 'old'`)).n, 0);

const users = Array.from({ length: 6 }, (_, i) => `00000000-0000-0000-0000-00000000000${i + 1}`);
for (const u of users) await db.query('insert into auth.users values ($1)', [u]);

// Quota: per user and site-wide.
let q = await one(`select public.consume_ai_quota_for($1) as q`, [users[0]]);
assert.equal(q.q.requests, 1); assert.equal(q.q.total, 1); assert.ok(q.q.first_seen);
q = await one(`select public.consume_ai_quota_for($1) as q`, [users[0]]);
assert.equal(q.q.requests, 2);
q = await one(`select public.consume_ai_quota_for($1) as q`, [users[1]]);
assert.equal(q.q.requests, 1); assert.equal(q.q.total, 3);
await assert.rejects(db.query(`select public.consume_ai_quota_for(null)`));

// Plus claims: three accounts per subscription, refunds end it, reversals restore it.
const claim = async (u, tx = '2000000123456789') => (await one(`select public.claim_plus_for($1, $2) as ok`, [u, tx])).ok;
assert.equal(await claim(users[0]), true);
assert.equal(await claim(users[1]), true);
assert.equal(await claim(users[2]), true);
assert.equal(await claim(users[3]), false, 'fourth account refused');
assert.equal(await claim(users[0]), true, 'existing account keeps it');
assert.equal(await claim(users[0], 'abc'), false);
await db.query(`update word7000_private.plus_claims set last_used = now() - interval '31 days' where user_id = $1`, [users[2]]);
assert.equal(await claim(users[3]), true, 'a month-old claim frees a place');
await db.query(`select public.record_plus_notice('2000000123456789', 'REFUND', true)`);
assert.equal(await claim(users[0]), false, 'refunded');
await db.query(`select public.record_plus_notice('2000000123456789', 'REFUND_REVERSED', false)`);
assert.equal(await claim(users[0]), true, 'reversal restores');
await db.query(`select public.record_plus_notice('drop table x', 'REFUND', true)`);
assert.equal((await one(`select count(*)::int as n from word7000_private.plus_revocations`)).n, 0);

// Grants: only the service role may call them.
for (const fn of ['consume_ai_quota_for(uuid)', 'claim_plus_for(uuid, text)', 'record_plus_notice(text, text, boolean)']) {
  for (const role of ['anon', 'authenticated', 'service_role']) {
    const ok = (await one(`select has_function_privilege($1, 'public.${fn}', 'execute') as ok`, [role])).ok;
    assert.equal(ok, role === 'service_role', `${role} on ${fn}`);
  }
}
assert.equal((await one(`select has_function_privilege('authenticated', 'public.consume_ai_quota()', 'execute') as ok`)).ok, false);
assert.equal((await one(`select count(*)::int as n from pg_proc where proname = 'consume_ai_request'`)).n, 0);

// Live Activity devices: shape checks and at most five per learner.
const token = 'ab'.repeat(32);
const reg = (u, d, t = token) => db.query(
  `insert into live_activity_devices (user_id, device_id, push_to_start_token, registration_updated_at) values ($1, $2, $3, now() + ($4 || ' seconds')::interval)
   on conflict (user_id, device_id) do update set push_to_start_token = excluded.push_to_start_token`, [u, d, t, String(Number(d.replace(/\D/g, '') || 0))]);
await assert.rejects(reg(users[4], 'd1', 'abc'), /token_shape/);
await assert.rejects(reg(users[4], 'x'.repeat(101)), /device_id_length/);
for (let i = 1; i <= 7; i += 1) await reg(users[4], `d${i}`);
const kept = (await db.query(`select device_id from live_activity_devices where user_id = $1 order by device_id`, [users[4]])).rows.map((r) => r.device_id);
assert.deepEqual(kept, ['d3', 'd4', 'd5', 'd6', 'd7']);
await reg(users[4], 'd7');
assert.equal((await one(`select count(*)::int as n from live_activity_devices where user_id = $1`, [users[4]])).n, 5);

// Synced data ceiling.
await db.query(`insert into profiles (id) values ($1)`, [users[0]]);
await assert.rejects(db.query(`update profiles set progress = jsonb_build_object('x', repeat(md5(random()::text), 300000)) where id = $1`, [users[0]]), /payload_size/);
console.log('migration checks passed');
await db.close();
