// Reports why a TestFlight tester can or cannot install the app: the beta
// groups, who is in each and how far their invitation got, which builds each
// group has, and where each recent build stands in Beta App Review. Read-only:
// it changes nothing in App Store Connect.
//
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY="$(cat AuthKey.p8)" node scripts/testflight-testers.mjs
//
// The log can be public, so tester emails are masked, names are left out, and
// a public link's URL and the review contact details are never printed (only
// whether they are set).
import crypto from 'node:crypto';

const BUNDLE_ID = 'com.rio.word7000';
const API = 'https://api.appstoreconnect.apple.com';
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
  if (!response.ok) throw new Error(`${response.status} ${target.replace(API, '')}: ${text.slice(0, 300)}`);
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

/** One section of the report; a failure is printed and the rest still runs. */
async function section(title, run) {
  console.log(`\n## ${title}`);
  try {
    await run();
  } catch (error) {
    console.log(`  (could not read: ${error.message})`);
  }
}

function mask(email) {
  const [user = '', domain = ''] = String(email ?? '').split('@');
  if (!domain) return '(no email)';
  const shown = user.length > 4 ? `${user.slice(0, 2)}***${user.slice(-3)}` : `${user.slice(0, 1)}***`;
  return `${shown}@${domain}`;
}

const day = (value) => (value ? String(value).slice(0, 16).replace('T', ' ') : '?');
const set = (value) => (value ? 'set' : 'MISSING');

const apps = await api(`/v1/apps?filter[bundleId]=${encodeURIComponent(BUNDLE_ID)}`);
const app = apps.data?.[0];
if (!app) throw new Error(`No app with bundle id ${BUNDLE_ID}`);
console.log(`# TestFlight testers for ${BUNDLE_ID} (app ${app.id})`);

const groupsById = new Map();
await section('Beta groups', async () => {
  const groups = await all(`/v1/apps/${app.id}/betaGroups?limit=50`);
  if (!groups.data.length) console.log('  No beta groups.');
  for (const group of groups.data) {
    groupsById.set(group.id, group);
    const a = group.attributes ?? {};
    console.log(`\n### ${a.name} — ${a.isInternalGroup ? 'INTERNAL' : 'EXTERNAL'}`);
    console.log(`  public link: ${a.publicLinkEnabled ? 'on' : 'off'}${a.publicLinkLimitEnabled ? ` (limit ${a.publicLinkLimit})` : ''}`
      + `; feedback: ${a.feedbackEnabled ? 'on' : 'off'}`
      + (a.isInternalGroup ? `; all builds automatically: ${a.hasAccessToAllBuilds ? 'yes' : 'no'}` : ''));
    const builds = await all(`/v1/betaGroups/${group.id}/builds?limit=50&fields[builds]=version,processingState,expired,uploadedDate`);
    const live = builds.data.filter((build) => !build.attributes?.expired);
    console.log(`  builds in this group: ${builds.data.length} (${live.length} not expired)`);
    for (const build of live.slice(0, 5)) {
      const b = build.attributes ?? {};
      console.log(`    - build ${b.version} uploaded ${day(b.uploadedDate)} ${b.processingState}`);
    }
    const testers = await all(`/v1/betaGroups/${group.id}/betaTesters?limit=200&fields[betaTesters]=email,inviteType,state`);
    console.log(`  testers: ${testers.data.length}`);
    for (const tester of testers.data) {
      const t = tester.attributes ?? {};
      console.log(`    - ${mask(t.email)}  state=${t.state ?? '?'}  invite=${t.inviteType ?? '?'}`);
    }
  }
});

await section('Every tester of this app (also ones added to a build without a group)', async () => {
  const testers = await all(`/v1/betaTesters?filter[apps]=${app.id}&limit=200&include=betaGroups&fields[betaTesters]=email,inviteType,state,betaGroups`);
  if (!testers.data.length) console.log('  No testers.');
  for (const tester of testers.data) {
    const t = tester.attributes ?? {};
    const groups = (tester.relationships?.betaGroups?.data ?? [])
      .map((ref) => groupsById.get(ref.id)?.attributes?.name ?? ref.id)
      .join(', ');
    console.log(`  - ${mask(t.email)}  state=${t.state ?? '?'}  invite=${t.inviteType ?? '?'}  groups=[${groups || 'none'}]`);
  }
});

await section('Recent builds and Beta App Review', async () => {
  const builds = await all(`/v1/builds?filter[app]=${app.id}&sort=-uploadedDate&limit=8`
    + '&include=buildBetaDetail,betaAppReviewSubmission,preReleaseVersion'
    + '&fields[builds]=version,processingState,expired,uploadedDate,usesNonExemptEncryption,buildBetaDetail,betaAppReviewSubmission,preReleaseVersion');
  for (const build of builds.data.slice(0, 8)) {
    const b = build.attributes ?? {};
    const rel = build.relationships ?? {};
    const detail = builds.included.get(`buildBetaDetails:${rel.buildBetaDetail?.data?.id}`)?.attributes ?? {};
    const review = builds.included.get(`betaAppReviewSubmissions:${rel.betaAppReviewSubmission?.data?.id}`)?.attributes;
    const version = builds.included.get(`preReleaseVersions:${rel.preReleaseVersion?.data?.id}`)?.attributes?.version ?? '?';
    console.log(`  - ${version} (${b.version}) uploaded ${day(b.uploadedDate)} ${b.processingState}${b.expired ? ' EXPIRED' : ''}`);
    console.log(`      internal=${detail.internalBuildState ?? '?'}  external=${detail.externalBuildState ?? '?'}`
      + `  beta review=${review?.betaReviewState ?? 'never submitted'}`
      + `  encryption=${b.usesNonExemptEncryption ?? 'unanswered'}`);
  }
  if (!builds.data.length) console.log('  No builds.');
});

await section('Test information (needed before external testers can install)', async () => {
  const localizations = await all(`/v1/apps/${app.id}/betaAppLocalizations?limit=50`);
  if (!localizations.data.length) console.log('  No test information in any language.');
  for (const item of localizations.data) {
    const a = item.attributes ?? {};
    console.log(`  - ${a.locale}: description ${set(a.description)}, feedback email ${set(a.feedbackEmail)}`
      + `, privacy policy ${set(a.privacyPolicyUrl)}`);
  }
  const detail = await api(`/v1/apps/${app.id}/betaAppReviewDetail`);
  const d = detail.data?.attributes ?? {};
  console.log(`  review contact: name ${set(d.contactFirstName && d.contactLastName)}, email ${set(d.contactEmail)}, phone ${set(d.contactPhone)}`);
  console.log(`  sign-in required: ${d.demoAccountRequired ? 'yes' : 'no'}${d.demoAccountRequired ? `, demo account ${set(d.demoAccountName && d.demoAccountPassword)}` : ''}`);
});
