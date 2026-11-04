import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

// Checks the remote word content migration on PGlite:
// node scripts/test-remote-content-migration.mjs path/to/@electric-sql/pglite/dist/index.js
const runtime = process.argv[2];
if (!runtime) throw new Error('Pass the path to @electric-sql/pglite/dist/index.js');
const { PGlite } = await import(pathToFileURL(runtime).href);
const db = new PGlite();
await db.exec(`create role anon; create role authenticated; create role service_role; grant usage on schema public to anon, authenticated;`);
await db.exec(await fs.readFile('supabase/migrations/20261104130000_remote_word_content.sql', 'utf8'));
const word = { id: 'pack-medical-symptom', word: 'symptom', partOfSpeech: 'n', pronunciation: '', meaningZh: '症狀', example: '', exampleZh: '', group: 'Level 1' };
await db.query(`insert into official_banks (id, mode, name_zh, words) values ('medical', 'english', '醫護英文', $1), ('old', 'english', '舊字庫', $1)`, [JSON.stringify([word])]);
await db.query(`update official_banks set active = false where id = 'old'`);
await db.query(`insert into content_corrections (mode, word_id, fields) values ('english', 'w0001', '{"meaningZh":"適應"}'), ('english', 'w0002', '{}')`);
await db.query(`update content_corrections set active = false where word_id = 'w0002'`);
await assert.rejects(db.query(`insert into official_banks (id, mode, name_zh, words) values ('Bad Id', 'english', 'x', '[]')`));
await assert.rejects(db.query(`insert into official_banks (id, mode, name_zh, words) values ('empty', 'english', 'x', '[]')`));
await assert.rejects(db.query(`insert into content_corrections (mode, word_id) values ('klingon', 'w1')`));

await db.exec('set role anon');
assert.deepEqual((await db.query('select id from official_banks')).rows.map((r) => r.id), ['medical']);
assert.deepEqual((await db.query('select word_id from content_corrections')).rows.map((r) => r.word_id), ['w0001']);
await assert.rejects(db.query(`update content_corrections set hidden = true`));
await assert.rejects(db.query(`insert into content_corrections (mode, word_id) values ('english', 'w9')`));
console.log('remote content migration ok');
