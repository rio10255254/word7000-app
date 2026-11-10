#!/usr/bin/env node
// Fills in the App Store version page in App Store Connect from the repo, so
// only what the API cannot do is left by hand: the version, its build, the
// app name and subtitle, store text and screenshots in zh-Hant and en-US,
// the review notes, and the subscription group's name where it can be set. It does not
// submit anything for review, change prices or availability, or touch the
// App Privacy answers. Running it again brings the page back in line with
// the repo; screenshots are only replaced when they differ.
//
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… \
//   node scripts/asc-prepare-version.mjs --bundle com.rio.word7000 --version 2.0.2 [--build 7]
//   node scripts/asc-prepare-version.mjs --version 2.0.2 --check-copy   (no Apple calls)
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const arg = (name, fallback) => (process.argv.includes(name) ? process.argv[process.argv.indexOf(name) + 1] : fallback);
const bundle = arg('--bundle', 'com.rio.word7000');
const versionString = arg('--version', '');
const wantedBuild = arg('--build', '');
if (!/^\d+(\.\d+){0,2}$/.test(versionString)) throw new Error('--version is required, e.g. 2.0.2');
const { ASC_KEY_ID: keyId, ASC_ISSUER_ID: issuer, ASC_PRIVATE_KEY: privateKey } = process.env;

const SUPPORT_URL = 'https://word7000-app.rio10255254.workers.dev/support.html';
const PRIVACY_URL = 'https://word7000-app.rio10255254.workers.dev/privacy.html';
const SCREENSHOT_TYPE = 'APP_IPHONE_67'; // 6.9" iPhone screenshots (1320 × 2868) go in this set
// The subscription group's name as subscribers see it in Settings.
const GROUP_NAMES = { 'zh-Hant': 'WordCat Premium', 'en-US': 'WordCat Premium' };

// ---- App Store Connect API -------------------------------------------------
const base64url = (data) => Buffer.from(data).toString('base64url');
function token() {
  const now = Math.floor(Date.now() / 1000);
  const head = base64url(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }));
  const body = base64url(JSON.stringify({ iss: issuer, iat: now, exp: now + 15 * 60, aud: 'appstoreconnect-v1' }));
  const signature = crypto.sign('sha256', Buffer.from(`${head}.${body}`), { key: privateKey, dsaEncoding: 'ieee-p1363' });
  return `${head}.${body}.${base64url(signature)}`;
}
async function api(method, url, body) {
  // App Store Connect answers 5xx now and then: try again a few times.
  let response;
  for (let attempt = 0; attempt < 5; attempt += 1) {
    response = await fetch(`https://api.appstoreconnect.apple.com${url}`, {
      method,
      headers: { Authorization: `Bearer ${token()}`, ...(body ? { 'Content-Type': 'application/json' } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    if (response.status < 500 || attempt === 4) break;
    await new Promise((resolve) => setTimeout(resolve, 3000 * (attempt + 1)));
  }
  if (response.status === 204) return {};
  const json = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(`${method} ${url} → ${response.status}: ${json.errors?.map((e) => e.detail ?? e.title).join('; ')}`);
  return json;
}
const get = (url) => api('GET', url);

const lines = [];
const say = (text = '') => { lines.push(text); console.log(text); };
const done = (text) => say(`- ✅ ${text}`);
const skip = (text) => say(`- ⏭️ ${text}`);
const fail = (text) => say(`- ❌ ${text}`);
// One failed step is reported and the rest still run.
async function step(label, work) {
  try { await work(); } catch (error) { fail(`${label}：${error.message}`); }
}

// ---- Store text from docs/App Store 上架文案.md --------------------------------
const doc = fs.readFileSync(new URL('../docs/App Store 上架文案.md', import.meta.url), 'utf8');
function section(heading) {
  const start = doc.indexOf(`\n## ${heading}`);
  if (start < 0) throw new Error(`No "## ${heading}" in the copy document`);
  const end = doc.indexOf('\n## ', start + 4);
  return doc.slice(start, end < 0 ? undefined : end);
}
function field(text, label) {
  const at = text.indexOf(`**${label}**`);
  if (at < 0) throw new Error(`No **${label}** in the copy document`);
  const after = text.slice(text.indexOf('\n', at) + 1);
  const next = after.search(/\n\*\*[^*\n]+\*\*/);
  return (next < 0 ? after : after.slice(0, next)).trim();
}
const zh = section('繁體中文');
const en = section('English');
const listing = {
  'zh-Hant': {
    name: field(zh, '名稱'), subtitle: field(zh, '副標題'), promotionalText: field(zh, '宣傳文字'),
    keywords: field(zh, '關鍵字'), description: field(zh, '描述'), whatsNew: field(zh, '這個版本的新功能'),
    screenshots: 'exports/app-store/zh-Hant',
  },
  'en-US': {
    name: field(en, 'Name'), subtitle: field(en, 'Subtitle'), promotionalText: field(en, 'Promotional text'),
    keywords: field(en, 'Keywords'), description: field(en, 'Description'), whatsNew: field(en, "What's New"),
    screenshots: 'exports/app-store/en-US',
  },
};
// Canada's store shows English (Canada); it gets the U.S. English listing.
listing['en-CA'] = { ...listing['en-US'] };
const reviewNotes = section('Review Notes (English)').split('\n').filter((l) => l.startsWith('- ')).map((l) => l.slice(2)).join('\n');
for (const [locale, l] of Object.entries(listing)) {
  if ([...l.name].length > 30 || [...l.subtitle].length > 30) throw new Error(`${locale}: name and subtitle must be at most 30 characters`);
  if ([...l.keywords].length > 100) throw new Error(`${locale}: keywords must be at most 100 characters`);
  if ([...l.promotionalText].length > 170) throw new Error(`${locale}: promotional text must be at most 170 characters`);
}

// --check-copy: show what would be sent, without contacting Apple.
if (process.argv.includes('--check-copy')) {
  for (const [locale, l] of Object.entries(listing)) {
    const shots = fs.readdirSync(l.screenshots).filter((f) => /\.(jpe?g|png)$/i.test(f)).length;
    console.log(`${locale}: ${l.name} | ${l.subtitle} | what's new ${[...l.whatsNew].length}/4000 | keywords ${[...l.keywords].length}/100 | promo ${[...l.promotionalText].length}/170 | description ${l.description.length} chars, starts "${l.description.slice(0, 30)}", ends "${l.description.slice(-30)}" | ${shots} screenshots`);
  }
  console.log(`review notes:\n${reviewNotes}`);
  process.exit(0);
}
if (!keyId || !issuer || !privateKey) throw new Error('ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY are required');

say(`# 準備 App Store ${versionString} 版本頁（${bundle}）`);
say('不會送審，也不會改價格、上架地區或隱私權問卷。');
const app = (await get(`/v1/apps?filter[bundleId]=${encodeURIComponent(bundle)}&limit=1`)).data[0];
if (!app) throw new Error(`No app with bundle id ${bundle}`);

// ---- The version ------------------------------------------------------------
say('\n## 版本');
const editable = ['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED', 'INVALID_BINARY'];
const versions = (await get(`/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS&limit=20`)).data;
let version = versions.find((v) => v.attributes.versionString === versionString);
if (version && !editable.includes(version.attributes.appVersionState ?? version.attributes.appStoreState)) {
  throw new Error(`${versionString} is ${version.attributes.appVersionState ?? version.attributes.appStoreState} and can no longer be edited`);
}
if (!version) {
  const other = versions.find((v) => editable.includes(v.attributes.appVersionState ?? v.attributes.appStoreState));
  if (other) {
    // Only one version can be in preparation; rename it rather than fail.
    version = (await api('PATCH', `/v1/appStoreVersions/${other.id}`, { data: { type: 'appStoreVersions', id: other.id, attributes: { versionString, releaseType: 'MANUAL' } } })).data;
    done(`把準備中的 ${other.attributes.versionString} 改成 ${versionString}`);
  } else {
    version = (await api('POST', '/v1/appStoreVersions', {
      data: { type: 'appStoreVersions', attributes: { platform: 'IOS', versionString, releaseType: 'MANUAL' },
        relationships: { app: { data: { type: 'apps', id: app.id } } } },
    })).data;
    done(`建立 ${versionString} 版本頁`);
  }
} else skip(`${versionString} 版本頁已經有了`);
if (version.attributes.releaseType !== 'MANUAL') {
  await step('發布方式', async () => {
    await api('PATCH', `/v1/appStoreVersions/${version.id}`, { data: { type: 'appStoreVersions', id: version.id, attributes: { releaseType: 'MANUAL' } } });
    done('發布方式設為「手動發布」：過審後由你按發布');
  });
} else skip('發布方式已是「手動發布」');

await step('建置版本', async () => {
  const filter = `filter[app]=${app.id}&filter[preReleaseVersion.version]=${encodeURIComponent(versionString)}&filter[processingState]=VALID${wantedBuild ? `&filter[version]=${encodeURIComponent(wantedBuild)}` : ''}`;
  const builds = (await get(`/v1/builds?${filter}&sort=-uploadedDate&limit=10`)).data;
  const build = builds.sort((a, b) => Number(b.attributes.version) - Number(a.attributes.version))[0];
  if (!build) { fail(`${versionString}${wantedBuild ? ` (${wantedBuild})` : ''} 還沒處理完成，晚點再跑一次`); return; }
  const current = (await get(`/v1/appStoreVersions/${version.id}/build`)).data;
  if (current?.id === build.id) { skip(`建置版本已是 (${build.attributes.version})`); return; }
  await api('PATCH', `/v1/appStoreVersions/${version.id}/relationships/build`, { data: { type: 'builds', id: build.id } });
  done(`選定建置版本 ${versionString} (${build.attributes.version})`);
});

// ---- Name, subtitle and privacy policy (App Information) ----------------------
say('\n## App 資訊（名稱、副標題）');
await step('App 資訊', async () => {
  const infos = (await get(`/v1/apps/${app.id}/appInfos`)).data;
  const info = infos.find((i) => ['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED'].includes(i.attributes.state ?? i.attributes.appStoreState))
    ?? infos.find((i) => !['READY_FOR_DISTRIBUTION', 'REPLACED_WITH_NEW_INFO'].includes(i.attributes.state ?? i.attributes.appStoreState));
  if (!info) { fail('找不到可編輯的 App 資訊'); return; }
  const existing = (await get(`/v1/appInfos/${info.id}/appInfoLocalizations?limit=50`)).data;
  for (const [locale, l] of Object.entries(listing)) {
    const attributes = { name: l.name, subtitle: l.subtitle, privacyPolicyUrl: PRIVACY_URL };
    const row = existing.find((x) => x.attributes.locale === locale);
    await step(`App 資訊（${locale}）`, async () => {
      if (row && Object.entries(attributes).every(([k, v]) => row.attributes[k] === v)) { skip(`${locale}：名稱「${l.name}」已是最新`); return; }
      if (row) await api('PATCH', `/v1/appInfoLocalizations/${row.id}`, { data: { type: 'appInfoLocalizations', id: row.id, attributes } });
      else await api('POST', '/v1/appInfoLocalizations', { data: { type: 'appInfoLocalizations', attributes: { locale, ...attributes }, relationships: { appInfo: { data: { type: 'appInfos', id: info.id } } } } });
      done(`${locale}：名稱「${l.name}」、副標題「${l.subtitle}」、隱私權網址${row ? '已更新' : '已新增這個語言'}`);
    });
  }
});

// ---- Store text and screenshots per language ----------------------------------
const md5 = (bytes) => crypto.createHash('md5').update(bytes).digest('hex');
async function uploadScreenshots(localizationId, folder, locale) {
  const files = fs.readdirSync(folder).filter((f) => /\.(jpe?g|png)$/i.test(f)).sort();
  if (!files.length) { fail(`${locale}：${folder} 沒有截圖`); return; }
  const sets = (await get(`/v1/appStoreVersionLocalizations/${localizationId}/appScreenshotSets?limit=50`)).data;
  let set = sets.find((s) => s.attributes.screenshotDisplayType === SCREENSHOT_TYPE);
  if (!set) {
    set = (await api('POST', '/v1/appScreenshotSets', { data: { type: 'appScreenshotSets', attributes: { screenshotDisplayType: SCREENSHOT_TYPE },
      relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: localizationId } } } } })).data;
  }
  const current = (await get(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=20`)).data;
  const wanted = files.map((f) => ({ name: f, bytes: fs.readFileSync(path.join(folder, f)) }));
  const processed = (s) => s.attributes.assetDeliveryState?.state === 'COMPLETE';
  const same = current.length === wanted.length && current.every((s, i) =>
    s.attributes.sourceFileChecksum === md5(wanted[i].bytes) && processed(s));
  if (same) { skip(`${locale}：${wanted.length} 張截圖已是最新`); return; }
  // Keep a processed screenshot that is already right; replace the rest,
  // including one stuck before processing (UPLOAD_COMPLETE for long).
  const keep = new Map();
  for (const file of wanted) {
    const match = current.find((s) => processed(s) && s.attributes.sourceFileChecksum === md5(file.bytes) && ![...keep.values()].includes(s.id));
    if (match) keep.set(file.name, match.id);
  }
  for (const shot of current) if (![...keep.values()].includes(shot.id)) await api('DELETE', `/v1/appScreenshots/${shot.id}`);
  const ids = [];
  let uploaded = 0;
  for (const file of wanted) {
    if (keep.has(file.name)) { ids.push(keep.get(file.name)); continue; }
    uploaded += 1;
    const reserved = (await api('POST', '/v1/appScreenshots', { data: { type: 'appScreenshots', attributes: { fileName: file.name, fileSize: file.bytes.length },
      relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: set.id } } } } })).data;
    for (const part of reserved.attributes.uploadOperations) {
      const headers = Object.fromEntries((part.requestHeaders ?? []).map((h) => [h.name, h.value]));
      const response = await fetch(part.url, { method: part.method, headers, body: file.bytes.subarray(part.offset, part.offset + part.length) });
      if (!response.ok) throw new Error(`uploading ${file.name}: ${response.status}`);
    }
    await api('PATCH', `/v1/appScreenshots/${reserved.id}`, { data: { type: 'appScreenshots', id: reserved.id, attributes: { uploaded: true, sourceFileChecksum: md5(file.bytes) } } });
    ids.push(reserved.id);
  }
  await api('PATCH', `/v1/appScreenshotSets/${set.id}/relationships/appScreenshots`, { data: ids.map((id) => ({ type: 'appScreenshots', id })) });
  done(`${locale}：重新上傳 ${uploaded} 張 6.9 吋 iPhone 截圖，保留已處理好的 ${ids.length - uploaded} 張，共 ${ids.length} 張依序排好`);
}

say('\n## 各語言的描述、關鍵字、截圖');
const versionLocalizations = (await get(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=50`)).data;
for (const [locale, l] of Object.entries(listing)) {
  await step(`版本文案（${locale}）`, async () => {
    const attributes = { description: l.description, keywords: l.keywords, promotionalText: l.promotionalText, supportUrl: SUPPORT_URL,
      whatsNew: l.whatsNew };
    let row = versionLocalizations.find((x) => x.attributes.locale === locale);
    if (row && Object.entries(attributes).every(([k, v]) => row.attributes[k] === v)) skip(`${locale}：描述、關鍵字、宣傳文字、支援網址已是最新`);
    else if (row) {
      await api('PATCH', `/v1/appStoreVersionLocalizations/${row.id}`, { data: { type: 'appStoreVersionLocalizations', id: row.id, attributes } });
      done(`${locale}：描述（${l.description.length} 字）、關鍵字、宣傳文字、支援網址已更新`);
    } else {
      row = (await api('POST', '/v1/appStoreVersionLocalizations', { data: { type: 'appStoreVersionLocalizations', attributes: { locale, ...attributes },
        relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } } } })).data;
      done(`${locale}：新增這個語言，填好描述、關鍵字、宣傳文字、支援網址`);
    }
    await uploadScreenshots(row.id, l.screenshots, locale);
  });
}

// ---- Review notes ---------------------------------------------------------------
say('\n## 審查資訊');
await step('審查備註', async () => {
  const detail = (await get(`/v1/appStoreVersions/${version.id}/appStoreReviewDetail`).catch(() => ({}))).data;
  const attributes = { notes: reviewNotes, demoAccountRequired: false };
  if (detail && detail.attributes.notes === reviewNotes && detail.attributes.demoAccountRequired === false) skip('審查備註已是最新');
  else if (detail) { await api('PATCH', `/v1/appStoreReviewDetails/${detail.id}`, { data: { type: 'appStoreReviewDetails', id: detail.id, attributes } }); done('審查備註已更新，不需要示範帳號'); }
  else { await api('POST', '/v1/appStoreReviewDetails', { data: { type: 'appStoreReviewDetails', attributes, relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } } } }); done('審查備註已填，不需要示範帳號'); }
  const contact = detail?.attributes ?? {};
  if (!contact.contactFirstName || !contact.contactLastName || !contact.contactPhone || !contact.contactEmail) {
    say('- 👀 審查聯絡人（姓名、電話、Email）要你自己填');
  }
});

// ---- Subscription group's name ---------------------------------------------------
say('\n## 訂閱群組名稱');
await step('訂閱群組名稱', async () => {
  for (const group of (await get(`/v1/apps/${app.id}/subscriptionGroups?limit=10`)).data) {
    const names = (await get(`/v1/subscriptionGroups/${group.id}/subscriptionGroupLocalizations?limit=20`)).data;
    for (const [locale, name] of Object.entries(GROUP_NAMES)) {
      // An approved name cannot be edited; a change to it is a second row, waiting for review.
      const rows = names.filter((n) => n.attributes.locale === locale);
      const same = rows.find((n) => n.attributes.name === name);
      if (same) { skip(`${locale}：已是「${name}」（${same.attributes.state}）`); continue; }
      const row = rows.find((n) => n.attributes.state !== 'APPROVED' && n.attributes.state !== 'ACTIVE');
      if (rows.length && !row) { fail(`${locale}：「${rows[0].attributes.name}」已核准，API 不能改，請在 App Store Connect 改`); continue; }
      if (row) await api('PATCH', `/v1/subscriptionGroupLocalizations/${row.id}`, { data: { type: 'subscriptionGroupLocalizations', id: row.id, attributes: { name } } });
      else await api('POST', '/v1/subscriptionGroupLocalizations', { data: { type: 'subscriptionGroupLocalizations', attributes: { locale, name },
        relationships: { subscriptionGroup: { data: { type: 'subscriptionGroups', id: group.id } } } } });
      done(`${locale}：${row ? `「${row.attributes.name}」改成` : '新增'}「${name}」，跟 ${versionString} 一起送審`);
    }
  }
});

say('\n## 還要你在 App Store Connect 做的');
say('- App 隱私權問卷（API 沒有提供）');
say('- 審查聯絡人、版權欄位');
say('- 確認後按「新增以供審查」→「提交」');
if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${lines.join('\n')}\n`);
