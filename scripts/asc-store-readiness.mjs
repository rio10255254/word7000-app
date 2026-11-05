#!/usr/bin/env node
// Read-only: checks what App Store Connect still needs before the app can be
// submitted for review: the version and its build, store text and screenshots
// in each language, review contact, age rating, and the subscriptions. It
// changes nothing. Agreements and the App Privacy answers are not in the API,
// so they are listed as checks to do by hand.
//
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… \
//   node scripts/asc-store-readiness.mjs --bundle com.rio.word7000 --version 2.0.2
import crypto from 'node:crypto';
import fs from 'node:fs';

const arg = (name, fallback) => (process.argv.includes(name) ? process.argv[process.argv.indexOf(name) + 1] : fallback);
const bundle = arg('--bundle', 'com.rio.word7000');
const wantedVersion = arg('--version', '');
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
async function api(path) {
  const response = await fetch(`https://api.appstoreconnect.apple.com${path}`, { headers: { Authorization: `Bearer ${token()}` } });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(`${response.status} ${json.errors?.map((e) => e.detail ?? e.title).join('; ') ?? ''}`.trim());
  return json;
}
const tryApi = (path) => api(path).catch((error) => ({ error: error.message }));

const lines = [];
let todo = 0;
const say = (text = '') => lines.push(text);
const ok = (text) => say(`- ✅ ${text}`);
const bad = (text) => { todo += 1; say(`- ❌ ${text}`); };
const hand = (text) => say(`- 👀 ${text}（API 查不到，要手動看）`);
const filled = (value) => typeof value === 'string' && value.trim().length > 0;
const lang = (locale) => ({ 'zh-Hant': '繁體中文', 'en-US': '英文（美國）' }[locale] ?? locale);

const app = (await api(`/v1/apps?filter[bundleId]=${encodeURIComponent(bundle)}&limit=1`)).data[0];
if (!app) throw new Error(`No app with bundle id ${bundle}`);
say(`# App Store 上架檢查：${app.attributes.name}（${bundle}）`);
say('只讀，不會改任何東西。');

// App information: name, subtitle, privacy policy, category, age rating.
say('\n## App 資訊');
const infos = await tryApi(`/v1/apps/${app.id}/appInfos?include=primaryCategory`);
const info = infos.data?.find((i) => !['READY_FOR_DISTRIBUTION', 'REPLACED_WITH_NEW_INFO'].includes(i.attributes.state ?? i.attributes.appStoreState)) ?? infos.data?.[0];
if (!info) bad(`讀不到 App 資訊：${infos.error ?? '沒有資料'}`);
else {
  const category = info.relationships?.primaryCategory?.data?.id;
  category ? ok(`主要類別：${category}`) : bad('還沒選主要類別');
  const localizations = (await tryApi(`/v1/appInfos/${info.id}/appInfoLocalizations?limit=50`)).data ?? [];
  for (const locale of ['zh-Hant', 'en-US']) {
    const l = localizations.find((x) => x.attributes.locale === locale);
    if (!l) { bad(`${lang(locale)}：還沒新增這個語言`); continue; }
    const a = l.attributes;
    const missing = [!filled(a.name) && '名稱', !filled(a.privacyPolicyUrl) && '隱私權政策網址'].filter(Boolean);
    missing.length ? bad(`${lang(locale)}：缺 ${missing.join('、')}`) : ok(`${lang(locale)}：名稱「${a.name}」${filled(a.subtitle) ? `，副標題「${a.subtitle}」` : '（沒有副標題，可留空）'}，隱私權網址已填`);
  }
  const extra = localizations.map((x) => x.attributes.locale).filter((x) => !['zh-Hant', 'en-US'].includes(x));
  if (extra.length) say(`- ℹ️ 其他語言：${extra.join('、')}`);
  const age = await tryApi(`/v1/appInfos/${info.id}/ageRatingDeclaration`);
  if (age.error) bad(`年齡分級：讀不到（${age.error}）`);
  else {
    // Optional answers: the Kids category band, Korea's GRAC number and an age rating info page.
    const optional = new Set(['kidsAgeBand', 'gracRatingClassificationNumber', 'developerAgeRatingInfoUrl', 'koreaAgeRatingOverride', 'ageRatingOverride', 'ageRatingOverrideV2']);
    const unanswered = Object.entries(age.data?.attributes ?? {}).filter(([k, v]) => v === null && !optional.has(k)).map(([k]) => k);
    unanswered.length ? bad(`年齡分級問卷還有 ${unanswered.length} 題沒答：${unanswered.join('、')}`) : ok('年齡分級問卷已填完');
  }
}
const rights = app.attributes.contentRightsDeclaration;
rights ? ok(`第三方內容聲明：${rights === 'DOES_NOT_USE_THIRD_PARTY_CONTENT' ? '沒有使用第三方內容' : '有使用第三方內容並取得授權'}`) : bad('「App 資訊 → 內容版權」還沒回答');

// Price and availability.
say('\n## 價格與供應地區');
const schedule = await tryApi(`/v1/apps/${app.id}/appPriceSchedule?include=manualPrices,baseTerritory`);
schedule.error ? bad(`App 價格還沒設定（${schedule.error}）`) : ok(`App 價格已設定（基準地區 ${schedule.data?.relationships?.baseTerritory?.data?.id ?? '?'}）`);
const availability = await tryApi(`/v1/apps/${app.id}/appAvailabilityV2`);
if (availability.error) bad(`供應地區還沒設定（${availability.error}）`);
else {
  const territories = await tryApi(`/v2/appAvailabilities/${availability.data.id}/territoryAvailabilities?limit=200`);
  if (territories.error) bad(`讀不到供應地區（${territories.error}）`);
  else {
    const all = territories.data ?? [];
    const on = all.filter((t) => t.attributes.available);
    const states = [...new Set(all.map((t) => t.attributes.contentStatuses?.join('/')).filter(Boolean))];
    on.length ? ok(`在 ${on.length}${territories.links?.next ? '+' : ''} 個地區供應${states.length ? `（狀態：${states.join('、')}）` : ''}`) : bad(`${all.length} 個地區全都沒有供應（${states.join('、') || '未供應'}）：到「價格與供應狀況」把地區打開；狀態是 CANNOT_SELL 時也要確認付費 App 協議已生效`);
  }
}

// The version being prepared, its build, store text, screenshots and review details.
say('\n## 版本');
const versions = (await api(`/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS&limit=10`)).data;
for (const v of versions.slice(0, 4)) say(`- ℹ️ ${v.attributes.versionString}：${v.attributes.appVersionState ?? v.attributes.appStoreState}`);
const editable = ['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED', 'INVALID_BINARY', 'READY_FOR_REVIEW'];
const version = versions.find((v) => (wantedVersion ? v.attributes.versionString === wantedVersion : true) && editable.includes(v.attributes.appVersionState ?? v.attributes.appStoreState));
if (!version) {
  bad(`還沒有可編輯的 ${wantedVersion || ''} 版本：在 App Store Connect 左邊「iOS App」旁按 ＋ 新增版本 ${wantedVersion}`);
} else {
  ok(`${version.attributes.versionString} 版本頁已建立（${version.attributes.appVersionState ?? version.attributes.appStoreState}）`);
  const build = await tryApi(`/v1/appStoreVersions/${version.id}/build`);
  if (!build.data) bad('還沒選建置版本（Build）');
  else {
    const b = build.data.attributes;
    ok(`建置版本：${version.attributes.versionString} (${b.version})，${b.processingState}`);
    if (b.usesNonExemptEncryption == null) bad('這個建置還沒回答加密問題（選「沒有使用非豁免的加密」）');
  }
  version.attributes.copyright ? ok(`版權：${version.attributes.copyright}`) : bad('版權欄位空白（填「2026 你的名字」）');

  const vls = (await tryApi(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=50`)).data ?? [];
  for (const locale of ['zh-Hant', 'en-US']) {
    say(`\n### ${lang(locale)}`);
    const l = vls.find((x) => x.attributes.locale === locale);
    if (!l) { bad('這個版本還沒有這個語言'); continue; }
    const a = l.attributes;
    const missing = [!filled(a.description) && '描述', !filled(a.keywords) && '關鍵字', !filled(a.supportUrl) && '支援網址'].filter(Boolean);
    missing.length ? bad(`缺 ${missing.join('、')}`) : ok(`描述（${a.description.length} 字）、關鍵字、支援網址都有`);
    filled(a.promotionalText) ? ok('宣傳文字已填') : say('- ℹ️ 宣傳文字空白（選填）');
    const sets = (await tryApi(`/v1/appStoreVersionLocalizations/${l.id}/appScreenshotSets?limit=50`)).data ?? [];
    const iphone = [];
    for (const set of sets) {
      const shots = (await tryApi(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=20`)).data ?? [];
      const broken = shots.filter((s) => s.attributes.assetDeliveryState?.state && s.attributes.assetDeliveryState.state !== 'COMPLETE').length;
      const type = set.attributes.screenshotDisplayType;
      if (type.startsWith('APP_IPHONE')) iphone.push(shots.length);
      say(`- ${shots.length ? '✅' : '❌'} 截圖 ${type}：${shots.length} 張${broken ? `（${broken} 張還在處理或失敗）` : ''}`);
    }
    if (!iphone.some((n) => n > 0)) bad('還沒有 iPhone 截圖（上傳到「iPhone 6.9 吋顯示器」）');
  }

  say('\n### 審查資訊');
  const review = await tryApi(`/v1/appStoreVersions/${version.id}/appStoreReviewDetail`);
  if (!review.data) bad('審查資訊（聯絡人）還沒填');
  else {
    const r = review.data.attributes;
    const missing = [!filled(r.contactFirstName) && '名', !filled(r.contactLastName) && '姓', !filled(r.contactEmail) && 'Email', !filled(r.contactPhone) && '電話'].filter(Boolean);
    missing.length ? bad(`聯絡人缺 ${missing.join('、')}`) : ok('聯絡人姓名、Email、電話都有');
    filled(r.notes) ? ok('審查備註已填') : bad('審查備註空白（貼上架文案檔最下面「給審查人員的說明」）');
    r.demoAccountRequired ? say('- ℹ️ 勾了「需要登入資訊」；訪客就能用，可以取消勾選') : ok('不需要示範帳號');
  }
}

// Subscriptions: each needs a group name, localisations, prices and a review
// screenshot before it can be sent with the version.
say('\n## 訂閱');
const groups = (await tryApi(`/v1/apps/${app.id}/subscriptionGroups?limit=10`)).data ?? [];
if (!groups.length) bad('沒有訂閱群組');
for (const group of groups) {
  say(`\n### 群組：${group.attributes.referenceName}`);
  const gls = (await tryApi(`/v1/subscriptionGroups/${group.id}/subscriptionGroupLocalizations?limit=20`)).data ?? [];
  for (const locale of ['zh-Hant', 'en-US']) {
    const l = gls.find((x) => x.attributes.locale === locale);
    l ? ok(`群組顯示名稱（${lang(locale)}）：${l.attributes.name}${l.attributes.customAppName ? `，App 名稱「${l.attributes.customAppName}」` : ''}（${l.attributes.state ?? '?'}）`) : bad(`群組還沒有${lang(locale)}的顯示名稱`);
  }
  const subs = (await tryApi(`/v1/subscriptionGroups/${group.id}/subscriptions?limit=20`)).data ?? [];
  for (const sub of subs) {
    const a = sub.attributes;
    const ready = ['READY_TO_SUBMIT', 'WAITING_FOR_REVIEW', 'IN_REVIEW', 'APPROVED'].includes(a.state);
    say(`- ${ready ? '✅' : '❌'} ${a.productId}（${a.name}，${a.subscriptionPeriod}）：${a.state}`);
    if (!ready) todo += 1;
    const sls = (await tryApi(`/v1/subscriptions/${sub.id}/subscriptionLocalizations?limit=20`)).data ?? [];
    for (const locale of ['zh-Hant', 'en-US']) {
      const l = sls.find((x) => x.attributes.locale === locale);
      if (!l) bad(`  ${a.productId} 還沒有${lang(locale)}的名稱與描述`);
      else if (!filled(l.attributes.description)) bad(`  ${a.productId}（${lang(locale)}）缺描述`);
    }
    const prices = await tryApi(`/v1/subscriptions/${sub.id}/prices?include=territory&limit=200`);
    const priced = new Set((prices.data ?? []).map((p) => p.relationships?.territory?.data?.id)).size;
    priced ? say(`  - 價格：${priced}${prices.links?.next ? '+' : ''} 個地區`) : bad(`  ${a.productId} 還沒設定價格`);
    const shot = await tryApi(`/v1/subscriptions/${sub.id}/appStoreReviewScreenshot`);
    shot.data ? say('  - 審查用截圖：有') : bad(`  ${a.productId} 還沒上傳審查用截圖（付費頁截圖即可）`);
  }
}

say('\n## 要手動確認的');
hand('商務 → 協議：「付費 App」狀態是「有效」');
hand('App 隱私權：資料收集問卷已發布');
hand('版本頁「App 內購買項目與訂閱」已勾選要一起送審的訂閱');

say(`\n**還有 ${todo} 項要處理。**`);
const text = lines.join('\n');
console.log(text);
if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${text}\n`);
