import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

// No network or production credentials. CI can install PGlite 0.5.10 outside
// the app and pass its dist/index.js path as the first argument.
const runtime = process.argv[2];
if (!runtime) throw new Error('Pass the path to @electric-sql/pglite/dist/index.js (tested: 0.5.10)');
const { PGlite } = await import(pathToFileURL(runtime).href);
const db = new PGlite();
const root = new URL('../', import.meta.url);
const migrationName = '20261022120000_reminder_ownership_and_legacy_streak.sql';
const migration = await fs.readFile(new URL(`supabase/migrations/${migrationName}`, root), 'utf8');
const passed = [];
const uid = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const time = (n) => `2020-01-01T00:00:${String(n).padStart(2, '0')}.000Z`;
const rows = async (sql, params = []) => (await db.query(sql, params)).rows;
const test = async (name, run) => { await run(); passed.push(name); };
const asRole = async (role, user, run) => {
  assert(['authenticated', 'service_role', 'anon'].includes(role));
  await db.query("select set_config('request.jwt.claims', $1, false)", [JSON.stringify({ role, sub: user })]);
  await db.exec(`set role ${role}`);
  try { return await run(); } finally {
    await db.exec('reset role');
    await db.exec("select set_config('request.jwt.claims', '{}', false)");
  }
};
const auth = (n, run) => asRole('authenticated', uid(n), run);
const cron = (run) => asRole('service_role', uid(1), run);
const denied = async (run) => assert.rejects(run, (error) => error.code === '42501');
const insertDevice = async (n, extra = {}) => {
  const row = {
    user_id: uid(n), device_id: 'phone', push_to_start_token: `token-${n}`,
    time_zone: 'UTC', streak: 5, updated_at: time(1), ...extra,
  };
  const fields = Object.keys(row);
  return rows(`insert into public.live_activity_devices (${fields.join(',')})
    values (${fields.map((_, i) => `$${i + 1}`).join(',')}) returning *`, Object.values(row));
};
const upsertDevice = async (n, extra = {}) => {
  const row = {
    user_id: uid(n), device_id: 'phone', push_to_start_token: `token-${n}`,
    enabled: true, studied_today: 0, updated_at: time(2), ...extra,
  };
  const fields = Object.keys(row);
  return rows(`insert into public.live_activity_devices (${fields.join(',')})
    values (${fields.map((_, i) => `$${i + 1}`).join(',')})
    on conflict (user_id, device_id) do update set
      ${fields.filter((f) => !['user_id', 'device_id'].includes(f)).map((f) => `${f}=excluded.${f}`).join(',')}
    returning *`, Object.values(row));
};
const device = async (n) => (await rows('select * from public.live_activity_devices where user_id=$1', [uid(n)]))[0];
const claim = (kind) => cron(() => rows(`select * from public.claim_due_${kind}_live_activities()`));
const policySnapshot = () => rows(`select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
  from pg_policies where schemaname='public' order by tablename, policyname`);
const apply = async () => {
  await db.exec('begin');
  try { await db.exec(migration); await db.exec('commit'); }
  catch (error) { await db.exec('rollback'); throw error; }
};

try {
  await db.exec(`
    create role anon;
    create role authenticated;
    create role service_role bypassrls;
    create schema auth;
    create table auth.users(id uuid primary key, is_anonymous boolean not null default false);
    create function auth.jwt() returns jsonb language sql stable as
      $$ select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb $$;
    create function auth.uid() returns uuid language sql stable as
      $$ select (auth.jwt()->>'sub')::uuid $$;
    grant usage on schema auth, public to anon, authenticated, service_role;
    grant execute on all functions in schema auth to anon, authenticated, service_role;
  `);
  await db.exec(await fs.readFile(new URL('supabase/schema.sql', root), 'utf8'));
  // Test against the real baseline and every historical migration, not a
  // reduced table that accidentally omits RLS, defaults or payload columns.
  const history = (await fs.readdir(new URL('supabase/migrations/', root)))
    .filter((name) => name.endsWith('.sql') && name < migrationName).sort();
  for (const name of history) await db.exec(await fs.readFile(new URL(`supabase/migrations/${name}`, root), 'utf8'));
  await db.exec('grant select, insert, update, delete on all tables in schema public to anon, authenticated, service_role');
  for (let n = 1; n <= 30; n++) await db.query('insert into auth.users(id) values ($1)', [uid(n)]);
  const policiesBefore = await policySnapshot();
  await insertDevice(1, { push_to_start_token: 'ambiguous', updated_at: time(9) });
  await insertDevice(2, { push_to_start_token: 'ambiguous', updated_at: time(2) });
  await insertDevice(3, { updated_at: time(3) });

  await test('First deployment quarantines only preexisting shared tokens without deleting rows', async () => {
    await apply();
    assert.equal((await device(1)).enabled, false);
    assert.equal((await device(2)).enabled, false);
    assert.equal((await device(3)).enabled, true);
    assert.equal((await rows('select count(*)::int as n from public.live_activity_devices'))[0].n, 3);
    assert.deepEqual((await device(1)).registration_updated_at, (await device(1)).updated_at);
    assert.equal((await claim('streak')).length, 0);
    assert.equal((await claim('noon')).some((row) => row.push_to_start_token === 'ambiguous'), false);
  });
  await test('Fresh owner registration restores quarantined delivery; transaction rerun preserves it', async () => {
    const result = await auth(2, () => upsertDevice(2, { push_to_start_token: 'ambiguous', updated_at: time(10) }));
    assert.equal(result.length, 1);
    assert.equal(result[0].enabled, true);
    await cron(() => db.query('update public.live_activity_devices set updated_at=now() where user_id=$1', [uid(2)]));
    const before = await rows('select * from public.live_activity_devices order by user_id');
    await apply();
    assert.deepEqual(await rows('select * from public.live_activity_devices order by user_id'), before);
    assert.deepEqual(await policySnapshot(), policiesBefore);
  });

  await test('Authenticated role and trusted JWT are exercised, not just postgres writes', async () => {
    await auth(1, async () => {
      assert.deepEqual(await rows("select current_user as role, auth.jwt()->>'role' as jwt_role"),
        [{ role: 'authenticated', jwt_role: 'authenticated' }]);
      assert.equal((await rows('select * from public.live_activity_devices')).length, 1);
    });
  });
  await test('RLS blocks cross-account reads, inserts and updates', async () => {
    await auth(1, async () => {
      assert.equal((await rows('select * from public.live_activity_devices where user_id=$1', [uid(2)])).length, 0);
      assert.equal((await rows('update public.live_activity_devices set enabled=true where user_id=$1 returning *', [uid(2)])).length, 0);
      await denied(() => insertDevice(4));
    });
    await asRole('anon', null, async () => {
      assert.equal((await rows('select * from public.live_activity_devices')).length, 0);
      await denied(() => insertDevice(4));
    });
  });
  await test('Only service_role can claim reminders; private helpers expose no callable endpoint', async () => {
    for (const role of ['anon', 'authenticated']) await asRole(role, uid(1), async () => {
      for (const kind of ['streak', 'noon']) await denied(() => rows(`select * from public.claim_due_${kind}_live_activities()`));
      await denied(() => rows("select word7000_private.progress_calendar_date('2026-10-01')"));
    });
    const acl = await rows(`select p.proname, n.nspname,
      has_function_privilege('anon', p.oid, 'EXECUTE') as anon,
      has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated,
      has_function_privilege('service_role', p.oid, 'EXECUTE') as service
      from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where (n.nspname='word7000_private' and p.proname in
        ('guard_reminder_registration','progress_calendar_date','preserve_profile_streak'))
      or (n.nspname='public' and p.proname in
        ('claim_due_streak_live_activities','claim_due_noon_live_activities'))`);
    assert.equal(acl.length, 5);
    for (const row of acl) {
      assert.equal(row.anon, false); assert.equal(row.authenticated, false);
      assert.equal(row.service, row.nspname === 'public');
    }
    assert.deepEqual(await rows(`select relname, relrowsecurity from pg_class
      where oid in ('public.profiles'::regclass,'public.live_activity_devices'::regclass)
      order by relname`), [
      { relname: 'live_activity_devices', relrowsecurity: true },
      { relname: 'profiles', relrowsecurity: true },
    ]);
  });

  await db.exec('truncate public.live_activity_devices');
  await test('INSERT derives owner time from legacy updated_at, ignoring client owner-time field', async () => {
    const [row] = await auth(1, () => upsertDevice(1, {
      enabled: false, studied_today: 20, updated_at: time(10), registration_updated_at: '2099-01-01',
    }));
    assert.equal(new Date(row.updated_at).toISOString(), time(10));
    assert.deepEqual(row.registration_updated_at, row.updated_at);
  });
  await test('Stale UPSERT returns zero rows and cannot overwrite disabled/completed registration', async () => {
    const before = await device(1);
    assert.equal((await auth(1, () => upsertDevice(1, { enabled: true, studied_today: 19, updated_at: time(9) }))).length, 0);
    assert.deepEqual(await device(1), before);
  });
  await test('Equal timestamp different payload returns zero rows; stale direct UPDATE is also ignored', async () => {
    const before = await device(1);
    assert.equal((await auth(1, () => upsertDevice(1, { enabled: true, studied_today: 20, updated_at: time(10) }))).length, 0);
    assert.equal((await auth(1, () => rows(`update public.live_activity_devices
      set enabled=true,updated_at=$1,registration_updated_at='2099-01-01' where user_id=$2 returning *`, [time(9), uid(1)]))).length, 0);
    assert.deepEqual(await device(1), before);
  });
  await test('Cron error/claim metadata never promotes account ownership', async () => {
    await cron(() => db.query(`update public.live_activity_devices set updated_at=now(),
      registration_updated_at='2099-01-01', last_push_error='synthetic failure',
      activity_started_for_expires_at=now(), noon_activity_started_for_local_date=current_date,
      noon_activity_expires_at=now()+interval '1 day' where user_id=$1`, [uid(1)]));
    assert.equal(new Date((await device(1)).registration_updated_at).toISOString(), time(10));
  });
  await test('Identical equal-time lost-response retry returns OLD, preserving all cron metadata', async () => {
    const before = await device(1);
    const retry = await auth(1, () => upsertDevice(1, {
      enabled: false, studied_today: 20, updated_at: time(10), registration_updated_at: '2099-01-01',
      activity_started_for_expires_at: null, noon_activity_started_for_local_date: null,
      noon_activity_expires_at: null, last_push_error: null,
    }));
    assert.deepEqual(retry, [before]);
    assert.deepEqual(await device(1), before);
  });
  await test('Equal-time payload mismatch in each registration field remains rejected', async () => {
    const changes = { push_to_start_token: 'other', enabled: true, app_locale: 'en', time_zone: 'UTC',
      streak: 12, streak_expires_at: '2026-10-22', daily_target: 21, studied_today: 19,
      progress_date: '2026-10-22', reminder_minute: 721, activity_push_token: 'other' };
    const before = await device(1);
    for (const [key, value] of Object.entries(changes)) {
      const result = await auth(1, () => upsertDevice(1, {
        enabled: false, studied_today: 20, updated_at: time(10), [key]: value,
      }));
      assert.equal(result.length, 0, key);
      assert.deepEqual(await device(1), before, key);
    }
  });
  await test('Fresh registration older than cron time is accepted; no new client field required', async () => {
    const [row] = await auth(1, () => upsertDevice(1, { updated_at: time(11) }));
    assert.equal(row.enabled, true);
    assert.equal(new Date(row.registration_updated_at).toISOString(), time(11));
    assert.equal(row.reminder_minute, 720);
  });

  // A transaction fixes now() for all eligibility boundaries, even at midnight.
  await db.exec('begin');
  const [clock] = await rows(`select now()+interval '30 minutes' as expires,
    now()+interval '2 hours' as later, now()-interval '1 minute' as expired,
    timezone('UTC',now())::date::text as today,
    (timezone('UTC',now())::date+1)::text as tomorrow,
    extract(hour from timezone('UTC',now()))::int*60+extract(minute from timezone('UTC',now()))::int as minute`);
  const dueDevice = (n, extra = {}) => insertDevice(n, {
    streak_expires_at: clock.expires, reminder_minute: clock.minute, ...extra,
  });
  for (const [label, extra] of Object.entries({
    disabled: { enabled: false }, zeroStreak: { streak: 0 },
    noExpiry: { streak_expires_at: null }, outsideWindow: { streak_expires_at: clock.later },
    expired: { streak_expires_at: clock.expired }, alreadyClaimed: { activity_started_for_expires_at: clock.expires },
  })) await test(`Streak ranks ALL token rows before eligibility: newest ${label} suppresses old account`, async () => {
    await db.exec('truncate public.live_activity_devices');
    await dueDevice(1, { push_to_start_token: 'shared', updated_at: time(1) });
    await dueDevice(2, { push_to_start_token: 'shared', updated_at: time(2), ...extra });
    assert.equal((await claim('streak')).length, 0);
  });
  for (const [label, extra] of Object.entries({
    disabled: { enabled: false }, completed: { studied_today: 20, progress_date: clock.today },
    alreadyClaimed: { noon_activity_started_for_local_date: clock.today },
    invalidTimeZone: { time_zone: 'not/a-zone' },
    outsideWindow: { reminder_minute: (clock.minute + 120) % 1440 },
  })) await test(`Noon ranks ALL token rows before eligibility: newest ${label} suppresses old account`, async () => {
    await db.exec('truncate public.live_activity_devices');
    await dueDevice(1, { push_to_start_token: 'shared', updated_at: time(1) });
    await dueDevice(2, { push_to_start_token: 'shared', updated_at: time(2), ...extra });
    assert.equal((await claim('noon')).length, 0);
  });
  await test('Cron timestamp pollution cannot promote the old account in either claim function', async () => {
    await db.exec('truncate public.live_activity_devices');
    await dueDevice(1, { push_to_start_token: 'shared', updated_at: time(1) });
    await dueDevice(2, { push_to_start_token: 'shared', updated_at: time(2) });
    await cron(() => db.query('update public.live_activity_devices set updated_at=now() where user_id=$1', [uid(1)]));
    for (const kind of ['streak', 'noon']) {
      const claimed = await claim(kind);
      assert.deepEqual(claimed.map((row) => row.user_id), [uid(2)]);
      assert.equal(new Date(claimed[0].registration_updated_at).toISOString(), time(2));
      assert.equal((await claim(kind)).length, 0);
    }
  });
  await test('Independent tokens, stale daily progress and deterministic tie-breaks still work', async () => {
    await db.exec('truncate public.live_activity_devices');
    await dueDevice(1, { push_to_start_token: 'tied' });
    await dueDevice(2, { push_to_start_token: 'tied' });
    await dueDevice(3, { progress_date: '2020-01-01', studied_today: 20 });
    for (const kind of ['streak', 'noon']) {
      assert.deepEqual((await claim(kind)).map((r) => r.user_id).sort(), [uid(1), uid(3)]);
      assert.equal((await claim(kind)).length, 0);
    }
  });
  await db.exec('commit');

  const state = (last, count, freeze, daily = last) => ({
    lastStudyDate: last, streak: count, dailyProgressDate: daily,
    ...(freeze === undefined ? {} : { streakFreezeDate: freeze }),
  });
  const profileCases = [
    ['legacy idle on protected day', state('2026-10-01', 5, '2026-10-02'), state('2026-10-01', 0, undefined, '2026-10-03'), 5, '2026-10-02', '2026-10-01'],
    ['legacy study after protected day', state('2026-10-01', 5, '2026-10-02'), state('2026-10-03', 1), 6, '2026-10-02', '2026-10-03'],
    ['same study day', state('2026-10-03', 6, '2026-10-02'), state('2026-10-03', 1), 6, '2026-10-02', '2026-10-03'],
    ['next study day', state('2026-10-03', 6, '2026-10-02'), state('2026-10-04', 1), 7, '2026-10-02', '2026-10-04'],
    ['unprotected long gap restarts', state('2026-10-01', 50, '2026-09-20'), state('2026-10-04', 1), 1, '2026-09-20', '2026-10-04'],
    ['idle long gap resets', state('2026-10-01', 50, '2026-10-02'), state('2026-10-01', 0, undefined, '2026-10-04'), 0, '2026-10-02', '2026-10-01'],
    ['weekly cooldown blocks second gap', state('2026-10-03', 6, '2026-10-02'), state('2026-10-05', 1), 1, '2026-10-02', '2026-10-05'],
    ['unused protection covers gap', state('2026-10-01', 5), state('2026-10-03', 1), 6, '2026-10-02', '2026-10-03'],
    ['unused protection covers idle day', state('2026-10-01', 5), state('2026-10-01', 0, undefined, '2026-10-03'), 5, '2026-10-02', '2026-10-01'],
    ['seven-day boundary permits protection', state('2026-10-08', 5, '2026-10-02'), state('2026-10-10', 1), 6, '2026-10-09', '2026-10-10'],
    ['six-day boundary denies protection', state('2026-10-07', 5, '2026-10-02'), state('2026-10-09', 1), 1, '2026-10-02', '2026-10-09'],
    ['newer daily date is not a study date', state('2026-10-03', 6, '2026-10-02'), state('2026-10-01', 0, undefined, '2026-10-04'), 6, '2026-10-02', '2026-10-03'],
    ['latest observed date expires stale candidate', state('2026-10-01', 5, '2026-10-02', '2026-10-10'), state('2026-10-03', 1), 0, '2026-10-02', '2026-10-03'],
    ['stronger new streak does not spend protection', state('2026-10-01', 5), state('2026-10-03', 7), 7, undefined, '2026-10-03'],
    ['equal new streak does not spend protection', state('2026-10-01', 5), state('2026-10-03', 6), 6, undefined, '2026-10-03'],
    ['newest valid freeze wins', state('2026-10-03', 6, '2026-10-02'), state('2026-10-10', 1, '2026-10-09'), 1, '2026-10-09', '2026-10-10'],
    ['null cannot erase freeze', state('2026-10-03', 6, '2026-10-02'), state('2026-10-03', 1, null), 6, '2026-10-02', '2026-10-03'],
    ['old freeze cannot replace newer', state('2026-10-03', 6, '2026-10-02'), state('2026-10-03', 1, '2026-09-20'), 6, '2026-10-02', '2026-10-03'],
    ['invalid calendar date cannot erase freeze', state('2026-10-03', 6, '2026-10-02'), state('2026-10-03', 1, '2026-02-30'), 6, '2026-10-02', '2026-10-03'],
    ['malformed date cannot erase freeze', state('2026-10-03', 6, '2026-10-02'), state('2026-10-03', 1, 'infinity'), 6, '2026-10-02', '2026-10-03'],
    ['boolean cannot erase freeze', state('2026-10-03', 6, '2026-10-02'), state('2026-10-03', 1, true), 6, '2026-10-02', '2026-10-03'],
    ['invalid incoming study date uses valid evidence', state('2026-10-03', 6, '2026-10-02'), state('2026-02-30', 1, undefined, '2026-10-04'), 6, '2026-10-02', '2026-10-03'],
    ['invalid old count cannot resurrect streak', state('2026-10-01', 'bad'), state('2026-10-03', 1), 1, undefined, '2026-10-03'],
    ['invalid old freeze does not block valid gap', state('2026-10-01', 5, '2026-02-30'), state('2026-10-03', 1), 6, '2026-10-02', '2026-10-03'],
    ['leap-day calendar arithmetic', state('2024-02-28', 5), state('2024-03-01', 1), 6, '2024-02-29', '2024-03-01'],
  ];
  const writeProfile = (progress, upsert = false) => auth(1, async () => {
    const sql = upsert
      ? `insert into public.profiles(id, progress) values ($1,$2::jsonb)
         on conflict(id) do update set progress=excluded.progress returning progress`
      : 'update public.profiles set progress=$2::jsonb where id=$1 returning progress';
    return (await rows(sql, [uid(1), JSON.stringify(progress)]))[0].progress;
  });
  const seedProfile = async (progress) => {
    await db.query('delete from public.profiles where id=$1', [uid(1)]);
    await auth(1, () => db.query('insert into public.profiles(id,progress) values ($1,$2::jsonb)', [uid(1), JSON.stringify(progress)]));
  };
  for (const [name, old, incoming, expectedCount, expectedFreeze, expectedLast] of profileCases) {
    await test(`Profile: ${name} (UPDATE and UPSERT)`, async () => {
      for (const upsert of [false, true]) {
        await seedProfile(old);
        const payload = { ...incoming, words: { synthetic: { reviewCount: 3 } }, customFutureField: { retained: true }, studiedToday: 2 };
        const actual = await writeProfile(payload, upsert);
        assert.equal(actual.streak, expectedCount, name);
        assert.equal(actual.streakFreezeDate, expectedFreeze, name);
        assert.equal(actual.lastStudyDate, expectedLast, name);
        const { streak, streakFreezeDate, lastStudyDate, ...other } = actual;
        const { streak: a, streakFreezeDate: b, lastStudyDate: c, ...expectedOther } = payload;
        assert.deepEqual(other, expectedOther, 'Unrelated progress must remain exactly as uploaded');
      }
    });
  }
  await test('Parity gate: Oct1:5 -> Oct3:7 does not consume Oct2; Oct5 can still protect Oct4', async () => {
    await seedProfile(state('2026-10-01', 5));
    const first = await writeProfile(state('2026-10-03', 7));
    assert.equal(first.streakFreezeDate, undefined);
    const second = await writeProfile(state('2026-10-03', 0, undefined, '2026-10-05'));
    assert.equal(second.streak, 7);
    assert.equal(second.streakFreezeDate, '2026-10-04');
  });
  await test('Profile custom-sets-only write leaves progress byte-for-byte unchanged', async () => {
    await seedProfile(state('2026-10-01', 5, '2026-10-02'));
    const before = await rows('select progress from public.profiles where id=$1', [uid(1)]);
    await auth(1, () => db.query(`update public.profiles set custom_sets='{"sets":["synthetic"]}' where id=$1`, [uid(1)]));
    assert.deepEqual(await rows('select progress from public.profiles where id=$1', [uid(1)]), before);
  });
  await test('Profile RLS remains enforced after private SECURITY DEFINER trigger', async () => {
    await auth(2, async () => {
      assert.equal((await rows('select * from public.profiles where id=$1', [uid(1)])).length, 0);
      assert.equal((await rows("update public.profiles set progress='{}' where id=$1 returning *", [uid(1)])).length, 0);
      await denied(() => db.query("insert into public.profiles(id,progress) values ($1,'{}') on conflict(id) do update set progress=excluded.progress", [uid(1)]));
    });
    assert.deepEqual(await policySnapshot(), policiesBefore);
  });
  console.log(JSON.stringify({
    result: 'PASS', scope: 'Local synthetic PGlite database only; no production reads or writes',
    migration: migrationName,
    migrationSha256: createHash('sha256').update(migration).digest('hex'),
    appliedTwiceInsideTransactions: true, rlsPoliciesUnchanged: true,
    testsPassed: passed.length, tests: passed,
  }, null, 2));
} finally { await db.close(); }
