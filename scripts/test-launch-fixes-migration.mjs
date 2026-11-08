import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

// Checks 20261108120000_launch_fixes.sql on PGlite, on top of the baseline and
// every earlier migration (no network, no production data):
// node scripts/test-launch-fixes-migration.mjs path/to/@electric-sql/pglite/dist/index.js (tested: 0.5.10)
const runtime = process.argv[2];
if (!runtime) throw new Error('Pass the path to @electric-sql/pglite/dist/index.js');
const { PGlite } = await import(pathToFileURL(runtime).href);
const db = new PGlite();
const root = new URL('../', import.meta.url);
const migrationName = '20261108120000_launch_fixes.sql';
const passed = [];
const uid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const rows = async (sql, params = []) => (await db.query(sql, params)).rows;
const one = async (sql, params = []) => Object.values((await rows(sql, params))[0])[0];
const test = async (name, run) => { await run(); passed.push(name); };

try {
  await db.exec(`
    create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth;
    create table auth.users(id uuid primary key, is_anonymous boolean not null default false,
      created_at timestamptz not null default now(), deleted_at timestamptz);
    create function auth.jwt() returns jsonb language sql stable as
      $$ select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb $$;
    create function auth.uid() returns uuid language sql stable as $$ select (auth.jwt()->>'sub')::uuid $$;
    grant usage on schema auth, public to anon, authenticated, service_role;
    grant execute on all functions in schema auth to anon, authenticated, service_role;
  `);
  await db.exec(await fs.readFile(new URL('supabase/schema.sql', root), 'utf8'));
  const names = (await fs.readdir(new URL('supabase/migrations/', root))).filter((name) => name.endsWith('.sql')).sort();
  assert(names.includes(migrationName));
  for (const name of names.filter((name) => name <= migrationName)) {
    await db.exec(await fs.readFile(new URL(`supabase/migrations/${name}`, root), 'utf8'));
  }
  // Applying it twice (a rerun) must work too.
  await db.exec(await fs.readFile(new URL(`supabase/migrations/${migrationName}`, root), 'utf8'));
  for (let n = 1; n <= 40; n++) await db.query('insert into auth.users(id) values ($1)', [uid(n)]);

  const at = (days) => new Date(Date.now() + days * 86_400_000).toISOString();
  const claim = (user, original, transaction, expires, purchased = at(-1)) =>
    one('select public.claim_plus_subscription($1, $2, $3, $4, $5)', [uid(user), original, transaction, expires, purchased]);
  const refund = (original, transaction, expires, type, revoked) =>
    db.query('select public.record_plus_refund($1, $2, $3, $4, $5)', [original, transaction, expires, type, revoked]);
  const renewal = (original, grace, signed) => db.query('select public.record_plus_renewal($1, $2, $3)', [original, grace, signed]);

  await test('A current subscription is Plus; malformed or missing ids are not', async () => {
    assert.equal(await claim(1, '100', '101', at(20)), true);
    assert.equal(await claim(1, 'abc', '101', at(20)), false);
    assert.equal(await claim(1, '100', null, at(20)), false);
    assert.equal(await claim(1, '100', '101', null), false);
  });
  await test('A refund ends the refunded period and earlier ones, not a later renewal of the same subscription', async () => {
    await refund('200', '202', at(5), 'REFUND', true);
    assert.equal(await claim(2, '200', '202', at(5)), false, 'the refunded transaction');
    assert.equal(await claim(2, '200', '201', at(-25 + 30 - 1)), false, 'an earlier period');
    assert.equal(await claim(2, '200', '203', at(35)), true, 'the next renewal (new transaction id, same original id)');
    assert.equal(await claim(3, '300', '301', at(5)), true, 'another subscription is untouched');
  });
  await test('A reversed refund restores the refunded transaction; repeats are harmless', async () => {
    await refund('200', '202', at(5), 'REFUND', true);
    await refund('200', '202', null, 'REFUND_REVERSED', false);
    await refund('200', '202', null, 'REFUND_REVERSED', false);
    assert.equal(await claim(2, '200', '202', at(5)), true);
  });
  await test('A Family Sharing revocation ends only that family member transaction', async () => {
    await refund('400', '402', at(10), 'REVOKE', true);
    assert.equal(await claim(4, '400', '402', at(10)), false);
    assert.equal(await claim(5, '400', '403', at(10)), true);
  });
  await test('A refund recorded before this migration refuses only what was bought before it', async () => {
    await db.query("insert into word7000_private.plus_revocations (original_transaction_id, notification_type) values ('500', 'REFUND')");
    assert.equal(await claim(6, '500', '501', at(10), at(-3)), false);
    assert.equal(await claim(6, '500', '502', at(10), null), false);
    assert.equal(await claim(6, '500', '503', at(30), at(1 / 24)), true, 'a renewal bought after the refund');
    // The old two-argument function keeps its old meaning for the old ai function.
    assert.equal(await one("select public.claim_plus_for($1, '500')", [uid(6)]), false);
    await refund('500', '501', null, 'REFUND_REVERSED', false);
    assert.equal(await claim(6, '500', '501', at(10), at(-3)), true);
  });
  await test('An ended period counts only during a billing grace period Apple reported', async () => {
    assert.equal(await claim(7, '700', '701', at(-1)), false, 'expired, no grace');
    await renewal('700', at(10), at(-0.5));
    assert.equal(await claim(7, '700', '701', at(-1)), true, 'in grace');
    await renewal('700', null, at(-0.9));
    assert.equal(await claim(7, '700', '701', at(-1)), true, 'an older notice does not end the grace period');
    assert.equal(await claim(7, '700', '701', at(-61)), false, 'a transaction long past is never enough');
    await renewal('700', null, at(-0.1));
    assert.equal(await claim(7, '700', '701', at(-1)), false, 'a newer notice without grace ends it');
    await renewal('700', at(-0.2), at(0));
    assert.equal(await claim(7, '700', '701', at(-1)), false, 'a grace period that ended');
    await refund('700', '701', at(-1), 'REFUND', true);
    await renewal('700', at(10), at(0.001));
    assert.equal(await claim(7, '700', '701', at(-1)), false, 'grace never brings back a refunded transaction');
  });
  await test('One subscription still stands for at most three accounts a month', async () => {
    for (const user of [11, 12, 13]) assert.equal(await claim(user, '800', '801', at(20)), true);
    assert.equal(await claim(14, '800', '801', at(20)), false);
    assert.equal(await claim(11, '800', '801', at(20)), true);
  });

  await test('A failed AI request is given back, at most 20 a day, never below zero', async () => {
    const today = (await rows("select (timezone('utc', now()))::date::text as d"))[0].d;
    const consume = () => db.query('select public.consume_ai_quota_for($1)', [uid(20)]);
    const giveBack = (date = today) => one('select public.refund_ai_quota_for($1, $2::date)', [uid(20), date]);
    for (let i = 0; i < 3; i++) await consume();
    assert.equal(await giveBack(), 2);
    assert.equal(await giveBack('2000-01-01'), null, 'another day is untouched');
    for (let i = 0; i < 30; i++) await consume();
    for (let i = 0; i < 25; i++) await giveBack();
    const usage = (await rows('select requests, refunds from word7000_private.ai_usage where user_id=$1', [uid(20)]))[0];
    assert.deepEqual(usage, { requests: 32 - 19, refunds: 20 });
    assert.equal(await one('select public.refund_ai_quota_for($1, $2::date)', [uid(21), today]), null, 'nothing to give back');
  });

  await test('Only the service role can call the new functions', async () => {
    const acl = await rows(`select p.proname, n.nspname,
      has_function_privilege('anon', p.oid, 'EXECUTE') as anon,
      has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated,
      has_function_privilege('service_role', p.oid, 'EXECUTE') as service
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where p.proname in ('claim_plus_subscription', 'record_plus_refund', 'record_plus_renewal', 'refund_ai_quota_for',
        'claim_plus_seat', 'claim_due_streak_live_activities', 'claim_due_noon_live_activities')`);
    assert.equal(acl.length, 7);
    for (const row of acl) {
      assert.equal(row.anon, false, row.proname);
      assert.equal(row.authenticated, false, row.proname);
      assert.equal(row.service, row.nspname === 'public', row.proname);
    }
  });

  // Reminders. A transaction fixes now() for every boundary.
  await db.exec('begin');
  const [clock] = await rows(`select now() + interval '30 minutes' as soon, now() + interval '1 day 30 minutes' as tomorrow,
    timezone('UTC', now())::date::text as today, (timezone('UTC', now())::date - 1)::text as yesterday,
    now() - interval '20 days' as old, now() - interval '1 day' as recent,
    extract(hour from timezone('UTC', now()))::int * 60 + extract(minute from timezone('UTC', now()))::int as minute`);
  const phone = async (user, device, extra = {}) => {
    const row = {
      user_id: uid(user), device_id: device, push_to_start_token: `${user}${device}`.padEnd(64, '0').replace(/[^0-9a-f]/g, 'a'),
      time_zone: 'UTC', streak: 5, streak_expires_at: clock.soon, reminder_minute: clock.minute, updated_at: clock.recent, ...extra,
    };
    const fields = Object.keys(row);
    await db.query(`insert into public.live_activity_devices (${fields.join(',')})
      values (${fields.map((_, i) => `$${i + 1}`).join(',')})`, Object.values(row));
  };
  const claimed = async (kind) => (await rows(`select user_id, device_id from public.claim_due_${kind}_live_activities()`))
    .map((row) => `${Number(row.user_id.slice(-12))}/${row.device_id}`).sort();

  await test('Streak card: not for a streak already kept on another phone, nor on a phone left unused', async () => {
    await db.exec('truncate public.live_activity_devices');
    await phone(30, 'a');
    await phone(30, 'b', { streak_expires_at: clock.tomorrow });   // studied there later
    await phone(31, 'a');
    await phone(31, 'b', { streak_expires_at: clock.recent });     // older deadline: says nothing
    await phone(32, 'a', { updated_at: clock.old });               // unused for 20 days
    await phone(32, 'b');
    await phone(33, 'a', { updated_at: clock.old });               // the only phone: still reminded
    assert.deepEqual(await claimed('streak'), ['31/a', '32/b', '33/a']);
    assert.deepEqual(await claimed('streak'), []);
  });
  await test('Daily goal card: not when the goal was reached on another phone, nor on a phone left unused', async () => {
    await db.exec('truncate public.live_activity_devices');
    await phone(34, 'a');
    await phone(34, 'b', { progress_date: clock.today, studied_today: 20 });       // done there today
    await phone(35, 'a');
    await phone(35, 'b', { progress_date: clock.yesterday, studied_today: 20 });   // done yesterday only
    await phone(36, 'a', { updated_at: clock.old });
    await phone(36, 'b');
    await phone(37, 'a', { updated_at: clock.old });
    await phone(38, 'a', { progress_date: clock.today, studied_today: 5, daily_target: 20 });
    await phone(38, 'b', { progress_date: clock.today, studied_today: 3, daily_target: 20 }); // neither done
    assert.deepEqual(await claimed('noon'), ['35/a', '35/b', '36/b', '37/a', '38/a', '38/b']);
    assert.deepEqual(await claimed('noon'), []);
  });
  await test('A phone shared by two accounts still goes to the account that registered it last', async () => {
    await db.exec('truncate public.live_activity_devices');
    await phone(39, 'a', { push_to_start_token: 'ab'.repeat(32), updated_at: clock.old });
    await phone(40, 'a', { push_to_start_token: 'ab'.repeat(32) });
    for (const kind of ['streak', 'noon']) assert.deepEqual(await claimed(kind), ['40/a']);
  });
  await db.exec('rollback');

  console.log(JSON.stringify({ result: 'PASS', migration: migrationName, testsPassed: passed.length, tests: passed }, null, 2));
} finally {
  await db.close();
}
