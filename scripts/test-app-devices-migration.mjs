import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

// Checks the per-phone version and model migration on PGlite:
// node scripts/test-app-devices-migration.mjs path/to/@electric-sql/pglite/dist/index.js
const runtime = process.argv[2];
if (!runtime) throw new Error('Pass the path to @electric-sql/pglite/dist/index.js');
const { PGlite } = await import(pathToFileURL(runtime).href);
const db = new PGlite();
const me = '00000000-0000-0000-0000-000000000001';
const guest = '00000000-0000-0000-0000-000000000002';
const phoneA = '10000000-0000-0000-0000-00000000000a';
const phoneB = '10000000-0000-0000-0000-00000000000b';
await db.exec(`
  create role anon; create role authenticated; create role service_role;
  create schema auth;
  create table auth.users (id uuid primary key, is_anonymous boolean default false);
  create table caller (id uuid);
  insert into caller values (null);
  create function auth.uid() returns uuid language sql as $$ select id from caller $$;
  create schema word7000_private;
  create table public.push_devices (token text primary key, user_id uuid not null references auth.users(id) on delete cascade,
    audience text, language text, updated_at timestamptz default now());
  insert into auth.users (id) values ('${me}');
  insert into auth.users (id, is_anonymous) values ('${guest}', true);
`);
// The earlier migration that creates app_installs and the four-argument report.
const remote = await fs.readFile('supabase/migrations/20261103130000_remote_control.sql', 'utf8');
await db.exec(remote.slice(0, remote.indexOf('-- Announcements for older versions only')));
await db.exec(await fs.readFile('supabase/migrations/20261105120000_app_devices.sql', 'utf8'));
const rows = async (sql, args = []) => (await db.query(sql, args)).rows;

await assert.rejects(db.query(`select public.report_app_version('2.0.2', 9, '26.1', 'zh', $1, 'iPhone18,1')`, [phoneA]), /sign in required/);
await db.query(`update caller set id = $1`, [me]);
// An older app: the account's version only.
await db.query(`select public.report_app_version('2.0.2', 8, '26.1', 'zh')`);
assert.equal((await rows(`select * from word7000_private.app_devices`)).length, 0);
// Two phones on one account are two rows; the account keeps its latest version.
await db.query(`select public.report_app_version('2.0.2', 9, '26.1', 'zh', $1, 'iPhone18,1')`, [phoneA]);
await db.query(`select public.report_app_version('2.0.2', 9, '18.6', 'en', $1, 'iPhone14,7')`, [phoneB]);
assert.deepEqual((await rows(`select model from word7000_private.app_devices order by model`)).map((r) => r.model), ['iPhone14,7', 'iPhone18,1']);
assert.equal((await rows(`select app_build from word7000_private.app_installs`))[0].app_build, 9);
// Reporting again updates the phone instead of adding one.
await db.query(`select public.report_app_version('2.0.2', 10, '26.2', 'zh', $1, 'iPhone18,1')`, [phoneA]);
assert.equal((await rows(`select count(*)::int as n from word7000_private.app_devices`))[0].n, 2);
assert.equal((await rows(`select app_build from word7000_private.app_devices where device_id = $1`, [phoneA]))[0].app_build, 10);
await assert.rejects(db.query(`select public.report_app_version('2.0.2', 10, '26.2', 'zh', $1, 'iPhone; drop')`, [phoneA]), /invalid model/);
// A guest's phone shows as a guest.
await db.query(`update caller set id = $1`, [guest]);
await db.query(`select public.report_app_version('2.0.2', 7, '26.0', 'zh', gen_random_uuid(), 'iPhone17,3')`);
const list = await rows(`select * from public.app_device_list()`);
assert.equal(list.length, 3);
assert.equal(list.find((r) => r.model === 'iPhone17,3').account, 'guest');
assert.equal(list.find((r) => r.model === 'iPhone18,1').account, 'apple');
// Deleting the account deletes its phones.
await db.query(`delete from auth.users where id = $1`, [me]);
assert.equal((await rows(`select count(*)::int as n from word7000_private.app_devices`))[0].n, 1);
console.log('App devices: all checks passed');
