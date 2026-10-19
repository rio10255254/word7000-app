import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

// Optional local PostgreSQL-compatible test runtime, kept outside app dependencies.
const runtime = process.argv[2];
if (!runtime) throw new Error('Pass the path to @electric-sql/pglite/dist/index.js');
const { PGlite } = await import(pathToFileURL(runtime).href);
const db = new PGlite();
try {
  await db.exec(`
    create role anon; create role authenticated; create role service_role;
    create table public.live_activity_devices (
      user_id text not null, device_id text not null, push_to_start_token text not null,
      enabled boolean not null default true, time_zone text not null default 'UTC',
      daily_target integer not null default 20, studied_today integer not null default 0,
      progress_date date, noon_activity_started_for_local_date date,
      noon_activity_expires_at timestamptz, last_push_error text,
      updated_at timestamptz not null default now(), primary key(user_id, device_id)
    );
  `);
  await db.exec(await fs.readFile('supabase/migrations/20261019150000_personal_reminder_time.sql', 'utf8'));
  const clock = (await db.query(`select extract(hour from timezone('UTC', now()))::int * 60 + extract(minute from timezone('UTC', now()))::int as minute`)).rows[0];
  const insert = async (id, extra = {}) => {
    const row = { user_id: id, device_id: 'iphone', push_to_start_token: id, reminder_minute: clock.minute, ...extra };
    const fields = Object.keys(row);
    await db.query(`insert into live_activity_devices (${fields.join(',')}) values (${fields.map((_, i) => '$' + (i + 1)).join(',')})`, Object.values(row));
  };
  await insert('due');
  await insert('completed', { studied_today: 20 });
  await db.exec("update live_activity_devices set progress_date = timezone('UTC',now())::date where user_id='completed'");
  await insert('old-progress', { studied_today: 20, progress_date: '2020-01-01' });
  await insert('disabled', { enabled: false });
  await insert('already-sent');
  await db.exec("update live_activity_devices set noon_activity_started_for_local_date = timezone('UTC',now())::date where user_id='already-sent'");
  await insert('old-account', { push_to_start_token: 'same-phone', updated_at: '2020-01-01' });
  await insert('new-account-disabled', { push_to_start_token: 'same-phone', enabled: false });
  await insert('old-enabled', { push_to_start_token: 'same-phone-2', updated_at: '2020-01-01' });
  await insert('new-enabled', { push_to_start_token: 'same-phone-2' });
  const actual = (await db.query('select user_id from claim_due_noon_live_activities()')).rows.map(row => row.user_id).sort();
  assert.deepEqual(actual, ['due', 'new-enabled', 'old-progress']);
  assert.equal((await db.query('select * from claim_due_noon_live_activities()')).rows.length, 0);
  await assert.rejects(insert('invalid-minute', { reminder_minute: 1440 }));
  console.log('Reminder migration passed: timing, completed goals, stale progress, disabled devices, account switching, deduplication, repeat calls, range validation.');
} finally {
  await db.close();
}
