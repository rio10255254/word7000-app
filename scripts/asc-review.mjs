#!/usr/bin/env node
// App Review for the App Store version, asked for by the owner each time:
//
//   cancel  Withdraw the version's submission that is waiting for review, so
//           its build, text or screenshots can change (it goes back to
//           "Developer Rejected"; submitting again starts a new wait).
//   submit  Submit the version for App Review once its build is the wanted
//           one and every screenshot has finished processing.
//   open    Make the app available in the given territories (after review,
//           when the owner releases it).
//
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… \
//   node scripts/asc-review.mjs cancel --bundle com.rio.word7000 --version 2.1.0
//   node scripts/asc-review.mjs submit --bundle com.rio.word7000 --version 2.1.0 --build 6
//   node scripts/asc-review.mjs open --bundle com.rio.word7000 --territories TWN,USA,CAN
import crypto from 'node:crypto';
import fs from 'node:fs';

const command = process.argv[2];
const arg = (name, fallback) => (process.argv.includes(name) ? process.argv[process.argv.indexOf(name) + 1] : fallback);
const bundle = arg('--bundle', 'com.rio.word7000');
const versionString = arg('--version', '');
const wantedBuild = arg('--build', '');
const territories = arg('--territories', '').split(',').map((t) => t.trim()).filter(Boolean);
if (!['cancel', 'submit', 'open'].includes(command)) throw new Error('usage: asc-review.mjs cancel|submit|open …');
if (command !== 'open' && !/^\d+(\.\d+){0,2}$/.test(versionString)) throw new Error('--version is required, e.g. 2.1.0');
if (command === 'submit' && !/^\d+$/.test(wantedBuild)) throw new Error('--build is required for submit, e.g. 6');
if (command === 'open' && !territories.length) throw new Error('--territories is required for open, e.g. TWN,USA,CAN');
const { ASC_KEY_ID: keyId, ASC_ISSUER_ID: issuer, ASC_PRIVATE_KEY: privateKey } = process.env;
if (!keyId || !issuer || !privateKey) throw new Error('ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY are required');

const base64url = (data) => Buffer.from(data).toString('base64url');
function token() {
  const now = Math.floor(Date.now() / 1000);
  const head = base64url(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }));
  const body = base64url(JSON.stringify({ iss: issuer, iat: now, exp: now + 15 * 60, aud: 'appstoreconnect-v1' }));
  const signature = crypto.sign('sha256', Buffer.from(`${head}.${body}`), { key: privateKey, dsaEncoding: 'ieee-p1363' });
  return `${head}.${body}.${base64url(signature)}`;
}
async function api(method, url, body) {
  const response = await fetch(`https://api.appstoreconnect.apple.com${url}`, {
    method,
    headers: { Authorization: `Bearer ${token()}`, ...(body ? { 'Content-Type': 'application/json' } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (response.status === 204) return {};
  const json = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(`${method} ${url} → ${response.status}: ${json.errors?.map((e) => e.detail ?? e.title).join('; ')}`);
  return json;
}
const get = (url) => api('GET', url);
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const lines = [];
const say = (text = '') => { lines.push(text); console.log(text); };
const finish = (code = 0) => {
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${lines.join('\n')}\n`);
  process.exit(code);
};

const app = (await get(`/v1/apps?filter[bundleId]=${encodeURIComponent(bundle)}&limit=1`)).data[0];
if (!app) throw new Error(`No app with bundle id ${bundle}`);
const stateOf = (v) => v.attributes.appVersionState ?? v.attributes.appStoreState;
const findVersion = async () => (await get(`/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS&filter[versionString]=${encodeURIComponent(versionString)}&limit=1`)).data[0];

/** The review submissions still open for this app, with the versions they hold. */
async function openSubmissions() {
  const subs = (await get(`/v1/apps/${app.id}/reviewSubmissions?filter[platform]=IOS&limit=20`)).data
    .filter((s) => !['COMPLETE', 'CANCELING', 'COMPLETING'].includes(s.attributes.state));
  const result = [];
  for (const sub of subs) {
    const items = await get(`/v1/reviewSubmissions/${sub.id}/items?include=appStoreVersion&limit=20`);
    const versionIds = (items.data ?? []).map((i) => i.relationships?.appStoreVersion?.data?.id).filter(Boolean);
    result.push({ sub, versionIds });
  }
  return result;
}

if (command === 'cancel') {
  say(`# 撤回 ${versionString} 的送審`);
  const version = await findVersion();
  if (!version) { say(`- ❌ 找不到 ${versionString}`); finish(1); }
  say(`- 目前狀態：${stateOf(version)}`);
  const pending = (await openSubmissions()).filter((s) => s.versionIds.includes(version.id) && s.sub.attributes.state !== 'READY_FOR_REVIEW');
  if (!pending.length) { say('- ⏭️ 沒有等待審查中的送審，不用撤回'); finish(0); }
  for (const { sub } of pending) {
    if (sub.attributes.state === 'IN_REVIEW') { say('- ❌ 已經在審查中，API 不撤回；要撤回請在 App Store Connect 操作'); finish(1); }
    await api('PATCH', `/v1/reviewSubmissions/${sub.id}`, { data: { type: 'reviewSubmissions', id: sub.id, attributes: { canceled: true } } });
    say(`- ✅ 已撤回送審（原狀態 ${sub.attributes.state}，送出於 ${sub.attributes.submittedDate ?? '-'}）`);
  }
  // Wait until the version can be edited again.
  for (let i = 0; i < 30; i += 1) {
    const now = await findVersion();
    if (['DEVELOPER_REJECTED', 'PREPARE_FOR_SUBMISSION'].includes(stateOf(now))) { say(`- ✅ ${versionString} 現在是 ${stateOf(now)}，可以修改`); finish(0); }
    await sleep(10_000);
  }
  say(`- 👀 還在撤回中（${stateOf(await findVersion())}），稍後再看`);
  finish(0);
}

if (command === 'submit') {
  say(`# 送審 ${versionString} (${wantedBuild})`);
  const version = await findVersion();
  if (!version) { say(`- ❌ 找不到 ${versionString}`); finish(1); }
  const state = stateOf(version);
  if (!['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED', 'READY_FOR_REVIEW'].includes(state)) {
    say(`- ❌ ${versionString} 是 ${state}，不能送審`); finish(1);
  }
  const build = (await get(`/v1/appStoreVersions/${version.id}/build`)).data;
  if (build?.attributes.version !== wantedBuild) { say(`- ❌ 版本頁的建置是 (${build?.attributes.version ?? '沒有'})，不是 (${wantedBuild})：先跑 store-prepare`); finish(1); }
  say(`- ✅ 建置 (${wantedBuild})，${build.attributes.processingState}`);
  // Every screenshot has to be processed before Apple takes the submission.
  const localizations = (await get(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=50`)).data;
  for (let i = 0; i < 30; i += 1) {
    let waiting = 0, failed = 0, total = 0;
    for (const l of localizations) {
      for (const set of (await get(`/v1/appStoreVersionLocalizations/${l.id}/appScreenshotSets?limit=50`)).data) {
        for (const shot of (await get(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=20`)).data) {
          total += 1;
          const s = shot.attributes.assetDeliveryState?.state;
          if (s === 'FAILED') failed += 1; else if (s !== 'COMPLETE') waiting += 1;
        }
      }
    }
    if (failed) { say(`- ❌ ${failed} 張截圖處理失敗：重新跑 store-prepare`); finish(1); }
    if (!waiting) { say(`- ✅ ${total} 張截圖都處理完成（${localizations.map((l) => l.attributes.locale).join('、')}）`); break; }
    if (i === 29) { say(`- ❌ 還有 ${waiting} 張截圖在處理，稍後再送`); finish(1); }
    await sleep(10_000);
  }
  // Reuse a draft submission if one is open, else start one.
  const open = await openSubmissions();
  if (open.some((s) => s.versionIds.includes(version.id) && ['WAITING_FOR_REVIEW', 'IN_REVIEW'].includes(s.sub.attributes.state))) {
    say('- ⏭️ 已經送審了'); finish(0);
  }
  let draft = open.find((s) => s.sub.attributes.state === 'READY_FOR_REVIEW')?.sub;
  if (!draft) {
    draft = (await api('POST', '/v1/reviewSubmissions', { data: { type: 'reviewSubmissions', attributes: { platform: 'IOS' },
      relationships: { app: { data: { type: 'apps', id: app.id } } } } })).data;
  }
  const items = (await get(`/v1/reviewSubmissions/${draft.id}/items?include=appStoreVersion&limit=20`)).data ?? [];
  if (!items.some((i) => i.relationships?.appStoreVersion?.data?.id === version.id)) {
    await api('POST', '/v1/reviewSubmissionItems', { data: { type: 'reviewSubmissionItems',
      relationships: { reviewSubmission: { data: { type: 'reviewSubmissions', id: draft.id } }, appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } } } });
  }
  const submitted = (await api('PATCH', `/v1/reviewSubmissions/${draft.id}`, { data: { type: 'reviewSubmissions', id: draft.id, attributes: { submitted: true } } })).data;
  say(`- ✅ 已送審：${submitted.attributes.state}，送出於 ${submitted.attributes.submittedDate ?? '-'}`);
  await sleep(5_000);
  say(`- ${versionString} 現在是 ${stateOf(await findVersion())}；發布方式是「手動發布」，過審後由你按發布`);
  finish(0);
}

if (command === 'open') {
  say(`# 打開地區：${territories.join('、')}`);
  const availability = (await get(`/v1/apps/${app.id}/appAvailabilityV2`)).data;
  const rows = (await get(`/v2/appAvailabilities/${availability.id}/territoryAvailabilities?include=territory&limit=200`)).data;
  for (const id of territories) {
    const row = rows.find((t) => t.relationships?.territory?.data?.id === id);
    if (!row) { say(`- ❌ ${id}：沒有這個地區`); continue; }
    if (row.attributes.available) { say(`- ⏭️ ${id}：已經供應`); continue; }
    await api('PATCH', `/v1/territoryAvailabilities/${row.id}`, { data: { type: 'territoryAvailabilities', id: row.id, attributes: { available: true } } });
    say(`- ✅ ${id}：已打開`);
  }
  finish(0);
}
