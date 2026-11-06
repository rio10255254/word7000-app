#!/usr/bin/env node
// Moves the testers of an internal TestFlight group that gets every build
// into an internal group that gets only the builds added to it, with the
// newest build the public testers have (master's), so nobody loses a build
// to test. The old group is deleted only with --delete-old, and only when the
// new group is checked to hold every tester and that build.
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… node scripts/testflight-move-group.mjs \
//     --bundle com.rio.word7000 --from "Word7000 Private Beta" --to "WordCat Internal" \
//     --public "Wordcat Public Testing 1" [--delete-old yes]
import crypto from 'node:crypto';
import { appendFileSync } from 'node:fs';

const arg = (name, fallback = '') => {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] ?? fallback : fallback;
};
const bundle = arg('bundle', 'com.rio.word7000');
const fromName = arg('from');
const toName = arg('to');
const publicName = arg('public', 'Wordcat Public Testing 1');
const deleteOld = arg('delete-old') === 'yes';
if (!fromName || !toName || fromName === toName) throw new Error('--from and --to are required and must differ');

const { ASC_KEY_ID: keyId, ASC_ISSUER_ID: issuer, ASC_PRIVATE_KEY: privateKey, GITHUB_STEP_SUMMARY: summary } = process.env;
if (!keyId || !issuer || !privateKey) throw new Error('ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY are required');
const say = (line = '') => { console.log(line); if (summary) appendFileSync(summary, line + '\n'); };
const b64 = (data) => Buffer.from(data).toString('base64url');
function token() {
  const now = Math.floor(Date.now() / 1000);
  const head = b64(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }));
  const body = b64(JSON.stringify({ iss: issuer, iat: now, exp: now + 900, aud: 'appstoreconnect-v1' }));
  return `${head}.${body}.${b64(crypto.sign('sha256', Buffer.from(`${head}.${body}`), { key: privateKey, dsaEncoding: 'ieee-p1363' }))}`;
}
async function api(method, path, body) {
  const response = await fetch(`https://api.appstoreconnect.apple.com${path}`, {
    method,
    headers: { Authorization: `Bearer ${token()}`, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  const json = text ? JSON.parse(text) : {};
  if (!response.ok) {
    const error = new Error(`${method} ${path} → ${response.status}: ${json.errors?.map((e) => e.detail ?? e.title).join('; ') ?? text}`);
    error.status = response.status;
    throw error;
  }
  return json;
}
const mask = (email = '') => email.replace(/^(.).*(@.*)$/, '$1…$2');

const app = (await api('GET', `/v1/apps?filter[bundleId]=${encodeURIComponent(bundle)}&limit=1`)).data[0];
if (!app) throw new Error(`No app with bundle id ${bundle}`);
const groups = (await api('GET', `/v1/apps/${app.id}/betaGroups?limit=200`)).data;
const named = (name) => groups.find((group) => group.attributes.name === name);
const from = named(fromName);
let to = named(toName);
const publicGroup = named(publicName);

say(`## TestFlight：把「${fromName}」搬到「${toName}」`);
say('');
if (!from) {
  if (to) { say(`「${fromName}」已經不在了；「${toName}」還在。沒有要做的事。`); process.exit(0); }
  throw new Error(`No TestFlight group named "${fromName}"`);
}
if (!from.attributes.isInternalGroup) throw new Error(`"${fromName}" is not an internal group; only internal groups are moved`);

// 1. The new group: internal, getting only the builds added to it.
if (!to) {
  to = (await api('POST', '/v1/betaGroups', { data: { type: 'betaGroups',
    attributes: { name: toName, isInternalGroup: true, hasAccessToAllBuilds: false },
    relationships: { app: { data: { type: 'apps', id: app.id } } } } })).data;
  say(`- 建立內部群組「${toName}」，只收到手動加入的建置。`);
} else {
  if (!to.attributes.isInternalGroup) throw new Error(`"${toName}" exists and is not an internal group`);
  if (to.attributes.hasAccessToAllBuilds) throw new Error(`"${toName}" exists and gets every build; pick another name`);
  say(`- 內部群組「${toName}」已經存在（只收手動加入的建置），沿用。`);
}

// 2. The testers.
const fromTesters = (await api('GET', `/v1/betaGroups/${from.id}/betaTesters?limit=200`)).data;
if (fromTesters.length) {
  await api('POST', `/v1/betaGroups/${to.id}/relationships/betaTesters`,
    { data: fromTesters.map((tester) => ({ type: 'betaTesters', id: tester.id })) });
}
say(`- 加入 ${fromTesters.length} 位測試人員：${fromTesters.map((t) => mask(t.attributes.email)).join('、') || '（沒有）'}`);

// 3. The newest build the public testers have (master's), so the testers
//    have a build to test right away.
let production;
if (publicGroup) {
  const builds = (await api('GET', `/v1/betaGroups/${publicGroup.id}/builds?limit=50`)).data
    .filter((build) => build.attributes.processingState === 'VALID' && !build.attributes.expired)
    .sort((a, b) => b.attributes.uploadedDate.localeCompare(a.attributes.uploadedDate));
  production = builds[0];
}
if (production) {
  await api('POST', `/v1/betaGroups/${to.id}/relationships/builds`, { data: [{ type: 'builds', id: production.id }] })
    .catch((error) => { if (error.status !== 409) throw error; });
  say(`- 加入正式線最新的建置 (${production.attributes.version})。`);
} else {
  say(`- ⚠️ 在「${publicName}」找不到可用的建置，沒有加入建置。`);
}

// 4. Check before anything is deleted.
const toTesters = new Set((await api('GET', `/v1/betaGroups/${to.id}/betaTesters?limit=200`)).data.map((t) => t.id));
const missing = fromTesters.filter((tester) => !toTesters.has(tester.id));
const toBuilds = (await api('GET', `/v1/betaGroups/${to.id}/builds?limit=50`)).data.map((b) => b.id);
const hasBuild = !production || toBuilds.includes(production.id);
const fresh = (await api('GET', `/v1/betaGroups/${to.id}`)).data;
say('');
say('| 檢查 | 結果 |');
say('|---|---|');
say(`| 新群組只收手動加入的建置 | ${fresh.attributes.hasAccessToAllBuilds ? '❌' : '✅'} |`);
say(`| 測試人員都在新群組 | ${missing.length ? `❌ 少 ${missing.length} 位` : `✅ ${fromTesters.length} 位`} |`);
say(`| 新群組有正式線最新建置 | ${hasBuild && production ? '✅' : '❌'} |`);
const verified = !fresh.attributes.hasAccessToAllBuilds && !missing.length && hasBuild && Boolean(production);

// 5. The old group, only when asked and only when all of it checked out.
say('');
if (!deleteOld) {
  say(`舊群組「${fromName}」留著沒刪。確認沒問題後，以 delete_old 再執行一次就會刪掉。`);
} else if (!verified) {
  throw new Error(`Not deleting "${fromName}": the checks above did not all pass`);
} else {
  await api('DELETE', `/v1/betaGroups/${from.id}`);
  say(`已刪除舊群組「${fromName}」。`);
}
