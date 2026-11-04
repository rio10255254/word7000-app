#!/usr/bin/env node
// Read-only: the latest builds, their Beta App Review state, and which
// TestFlight groups have them.
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… node scripts/asc-beta-status.mjs --bundle com.rio.word7000
import crypto from 'node:crypto';
import { appendFileSync } from 'node:fs';

const bundle = process.argv[process.argv.indexOf('--bundle') + 1] || 'com.rio.word7000';
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
async function api(path) {
  const response = await fetch(`https://api.appstoreconnect.apple.com${path}`, { headers: { Authorization: `Bearer ${token()}` } });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(`GET ${path} → ${response.status}: ${json.errors?.map((e) => e.detail ?? e.title).join('; ')}`);
  return json;
}
const state = { WAITING_FOR_REVIEW: '⏳ 等待審查', IN_REVIEW: '🔍 審查中', APPROVED: '✅ 已通過', REJECTED: '❌ 被退回' };

const app = (await api(`/v1/apps?filter[bundleId]=${encodeURIComponent(bundle)}&limit=1`)).data[0];
if (!app) throw new Error(`No app with bundle id ${bundle}`);
const builds = await api(`/v1/builds?filter[app]=${app.id}&sort=-uploadedDate&limit=8&include=preReleaseVersion,betaAppReviewSubmission,betaGroups`);
const included = new Map((builds.included ?? []).map((x) => [`${x.type}:${x.id}`, x]));
const ref = (rel) => rel?.data ? included.get(`${rel.data.type}:${rel.data.id}`) : undefined;
say('## 🧪 TestFlight 建置與 Beta 審查');
say('');
say('| 版本 | 建置 | 上傳 | 處理 | Beta 審查 | 測試群組 |');
say('|---|---|---|---|---|---|');
for (const build of builds.data) {
  const version = ref(build.relationships.preReleaseVersion)?.attributes.version ?? '?';
  const review = ref(build.relationships.betaAppReviewSubmission)?.attributes.betaReviewState;
  const groups = (build.relationships.betaGroups?.data ?? []).map((g) => included.get(`betaGroups:${g.id}`)?.attributes.name).filter(Boolean);
  say(`| ${version} | ${build.attributes.version} | ${build.attributes.uploadedDate.slice(0, 16).replace('T', ' ')} | ${build.attributes.processingState} | ${review ? state[review] ?? review : '沒送審'} | ${groups.join('、') || '-'} |`);
}
