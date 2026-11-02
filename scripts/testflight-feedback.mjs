// Downloads the feedback testers sent from TestFlight (screenshots with their
// comments, and crash reports) through the App Store Connect API, so it can
// be read alongside the code. Read-only: it changes nothing in App Store Connect.
//
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY="$(cat AuthKey.p8)" node scripts/testflight-feedback.mjs [out-dir]
//
// Writes REPORT.md, feedback.json and the screenshots to out-dir
// (default exports/testflight-feedback). Tester emails and names are left out.
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const BUNDLE_ID = 'com.rio.word7000';
const API = 'https://api.appstoreconnect.apple.com';
const outDir = process.argv[2] ?? 'exports/testflight-feedback';
const { ASC_KEY_ID, ASC_ISSUER_ID } = process.env;
const privateKey = (process.env.ASC_PRIVATE_KEY ?? '').replace(/\\n/g, '\n');
if (!ASC_KEY_ID || !ASC_ISSUER_ID || !privateKey.includes('PRIVATE KEY')) {
  console.error('Set ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY.');
  process.exit(1);
}

const base64url = (value) => Buffer.from(value).toString('base64url');

function token() {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: 'ES256', kid: ASC_KEY_ID, typ: 'JWT' }));
  const payload = base64url(JSON.stringify({ iss: ASC_ISSUER_ID, iat: now, exp: now + 1100, aud: 'appstoreconnect-v1' }));
  const signature = crypto.sign('sha256', Buffer.from(`${header}.${payload}`), { key: privateKey, dsaEncoding: 'ieee-p1363' });
  return `${header}.${payload}.${base64url(signature)}`;
}

async function api(target) {
  const response = await fetch(target.startsWith('http') ? target : `${API}${target}`, {
    headers: { Authorization: `Bearer ${token()}` },
  });
  const text = await response.text();
  if (!response.ok) throw new Error(`${response.status} ${target}: ${text.slice(0, 400)}`);
  return JSON.parse(text);
}

/** Every page of a list, following `links.next`, with included records by type and id. */
async function all(target) {
  const data = [];
  const included = new Map();
  let next = target;
  while (next) {
    const page = await api(next);
    data.push(...(page.data ?? []));
    for (const item of page.included ?? []) included.set(`${item.type}:${item.id}`, item);
    next = page.links?.next ?? null;
  }
  return { data, included };
}

function imageUrl(shot) {
  return String(shot.url ?? '')
    .replace('{w}', String(shot.width ?? 1200))
    .replace('{h}', String(shot.height ?? 2600))
    .replace('{f}', 'png');
}

const buildVersion = (item, included) => {
  const build = item.relationships?.build?.data;
  const record = build ? included.get(`builds:${build.id}`) : null;
  return record?.attributes?.version ?? '';
};

const apps = await api(`/v1/apps?filter[bundleId]=${encodeURIComponent(BUNDLE_ID)}`);
const app = apps.data?.[0];
if (!app) throw new Error(`No app with bundle id ${BUNDLE_ID}`);
fs.mkdirSync(path.join(outDir, 'screenshots'), { recursive: true });

const fields = 'fields[builds]=version';
const shots = await all(`/v1/apps/${app.id}/betaFeedbackScreenshotSubmissions?limit=50&include=build&${fields}`)
  .catch(async (error) => {
    console.warn(`Retrying screenshots without builds: ${error.message}`);
    return all(`/v1/apps/${app.id}/betaFeedbackScreenshotSubmissions?limit=50`);
  });
const crashes = await all(`/v1/apps/${app.id}/betaFeedbackCrashSubmissions?limit=50&include=build&${fields}`)
  .catch(async (error) => {
    console.warn(`Retrying crashes without builds: ${error.message}`);
    return all(`/v1/apps/${app.id}/betaFeedbackCrashSubmissions?limit=50`).catch((again) => {
      console.warn(`No crash feedback: ${again.message}`);
      return { data: [], included: new Map() };
    });
  });

const feedback = [];
for (const item of shots.data) {
  const a = item.attributes ?? {};
  const files = [];
  for (const [index, shot] of (a.screenshots ?? []).entries()) {
    const file = `screenshots/${item.id}-${index + 1}.png`;
    try {
      const response = await fetch(imageUrl(shot));
      if (!response.ok) throw new Error(String(response.status));
      fs.writeFileSync(path.join(outDir, file), Buffer.from(await response.arrayBuffer()));
      files.push(file);
    } catch (error) {
      console.warn(`Could not download a screenshot of ${item.id}: ${error.message}`);
    }
  }
  feedback.push({
    kind: 'screenshot', id: item.id, date: a.createdDate ?? '', build: buildVersion(item, shots.included),
    device: a.deviceModel ?? '', os: a.osVersion ?? '', comment: a.comment ?? '', screenshots: files,
  });
}
for (const item of crashes.data) {
  const a = item.attributes ?? {};
  let log = '';
  try {
    const crashLog = await api(`/v1/betaFeedbackCrashSubmissions/${item.id}/crashLog`);
    log = String(crashLog.data?.attributes?.logText ?? '').slice(0, 6000);
  } catch (error) {
    console.warn(`No crash log for ${item.id}: ${error.message}`);
  }
  feedback.push({
    kind: 'crash', id: item.id, date: a.createdDate ?? '', build: buildVersion(item, crashes.included),
    device: a.deviceModel ?? '', os: a.osVersion ?? '', comment: a.comment ?? '', log,
  });
}

feedback.sort((left, right) => String(right.date).localeCompare(String(left.date)));
fs.writeFileSync(path.join(outDir, 'feedback.json'), `${JSON.stringify(feedback, null, 1)}\n`);
const lines = [`# TestFlight feedback for ${BUNDLE_ID}`, '', `${feedback.length} reports, newest first.`, ''];
for (const item of feedback) {
  lines.push(`## ${item.date} · ${item.kind} · build ${item.build || '?'} · ${item.device} · iOS ${item.os}`);
  lines.push('', item.comment ? `> ${item.comment.replace(/\n/g, '\n> ')}` : '_(no comment)_', '');
  for (const file of item.screenshots ?? []) lines.push(`![](${file})`);
  if (item.log) lines.push('```', item.log, '```');
  lines.push('');
}
fs.writeFileSync(path.join(outDir, 'REPORT.md'), lines.join('\n'));
console.log(`${feedback.length} reports (${shots.data.length} screenshot, ${crashes.data.length} crash):`);
for (const item of feedback) {
  console.log(`- ${item.date} [${item.kind}] build ${item.build || '?'} ${item.device} iOS ${item.os}: ${item.comment.replace(/\s+/g, ' ').slice(0, 300)}`);
}
