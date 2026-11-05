#!/usr/bin/env node
// After an upload: waits for Apple to finish processing the build, fills in
// "What to Test", adds the build to a TestFlight group (the public one) and
// submits it for Beta App Review when Apple needs that.
//
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… \
//   node scripts/testflight-distribute.mjs --bundle com.rio.word7000 \
//     --version 2.0.1 --build 83 --group "Wordcat Public Testing 1" [--create-group yes] \
//     [--notes-zh "…"] [--notes-en "…"] [--wait-minutes 45]
import crypto from 'node:crypto';

const args = Object.fromEntries(process.argv.slice(2).reduce((pairs, value, index, all) => {
  if (value.startsWith('--')) pairs.push([value.slice(2), all[index + 1] ?? '']);
  return pairs;
}, []));
const { ASC_KEY_ID: keyId, ASC_ISSUER_ID: issuer, ASC_PRIVATE_KEY: privateKey } = process.env;
if (!keyId || !issuer || !privateKey) throw new Error('ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY are required');
for (const name of ['bundle', 'version', 'build', 'group']) if (!args[name]) throw new Error(`--${name} is required`);

const base64url = data => Buffer.from(data).toString('base64url');
function token() {
  const now = Math.floor(Date.now() / 1000);
  const head = base64url(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }));
  const body = base64url(JSON.stringify({ iss: issuer, iat: now, exp: now + 15 * 60, aud: 'appstoreconnect-v1' }));
  const signature = crypto.sign('sha256', Buffer.from(`${head}.${body}`), { key: privateKey, dsaEncoding: 'ieee-p1363' });
  return `${head}.${body}.${base64url(signature)}`;
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
    const error = new Error(`${method} ${path} → ${response.status}: ${json.errors?.map(e => e.detail ?? e.title).join('; ') ?? text}`);
    error.status = response.status;
    throw error;
  }
  return json;
}
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const q = encodeURIComponent;

const app = (await api('GET', `/v1/apps?filter[bundleId]=${q(args.bundle)}&limit=1`)).data[0];
if (!app) throw new Error(`No app with bundle id ${args.bundle}`);

// 1. Apple processes an upload for 5-30 minutes before it can be tested.
const deadline = Date.now() + Number(args['wait-minutes'] || 45) * 60_000;
let build;
for (;;) {
  const found = await api('GET', `/v1/builds?filter[app]=${app.id}&filter[version]=${q(args.build)}&filter[preReleaseVersion.version]=${q(args.version)}&limit=1`);
  build = found.data[0];
  const state = build?.attributes?.processingState;
  if (state === 'VALID') break;
  if (state === 'FAILED' || state === 'INVALID') throw new Error(`Apple could not process build ${args.build}: ${state}`);
  if (Date.now() > deadline) throw new Error(`Build ${args.build} was not ready in time (${state ?? 'not found yet'})`);
  console.log(`Waiting for Apple to process ${args.version} (${args.build}): ${state ?? 'not listed yet'}`);
  await sleep(60_000);
}
console.log(`Build ${args.version} (${args.build}) is processed.`);

// 2. What to Test, per language.
const notes = { 'zh-Hant': args['notes-zh'], 'en-US': args['notes-en'] };
if (Object.values(notes).some(Boolean)) {
  const existing = (await api('GET', `/v1/builds/${build.id}/betaBuildLocalizations`)).data;
  for (const [locale, whatsNew] of Object.entries(notes)) {
    if (!whatsNew) continue;
    const current = existing.find(item => item.attributes.locale === locale);
    if (current) {
      await api('PATCH', `/v1/betaBuildLocalizations/${current.id}`, { data: { type: 'betaBuildLocalizations', id: current.id, attributes: { whatsNew } } });
    } else {
      await api('POST', '/v1/betaBuildLocalizations', { data: { type: 'betaBuildLocalizations', attributes: { locale, whatsNew },
        relationships: { build: { data: { type: 'builds', id: build.id } } } } });
    }
    console.log(`What to Test set for ${locale}.`);
  }
}

// 3. Into the group. With --create-group yes, a missing group is made as an
// external group (testers are added, or its public link is turned on, in
// App Store Connect).
let group = (await api('GET', `/v1/betaGroups?filter[app]=${app.id}&filter[name]=${q(args.group)}&limit=1`)).data[0];
if (!group && args['create-group'] === 'yes') {
  group = (await api('POST', '/v1/betaGroups', { data: { type: 'betaGroups', attributes: { name: args.group },
    relationships: { app: { data: { type: 'apps', id: app.id } } } } })).data;
  console.log(`Created the TestFlight group "${args.group}".`);
  if (process.env.GITHUB_ACTIONS) console.log(`::notice::Created the TestFlight group "${args.group}". Add testers, or turn on its public link, in App Store Connect.`);
}
if (!group) throw new Error(`No TestFlight group named "${args.group}"`);
// Adding a build the group already has is fine.
await api('POST', `/v1/betaGroups/${group.id}/relationships/builds`, { data: [{ type: 'builds', id: build.id }] })
  .catch((error) => { if (error.status !== 409) throw error; });
console.log(`Added to "${args.group}".`);

// 4. External groups need Beta App Review; later builds of an approved
// version usually pass at once. Already submitted is fine.
if (!group.attributes.isInternalGroup) {
  try {
    await api('POST', '/v1/betaAppReviewSubmissions', { data: { type: 'betaAppReviewSubmissions',
      relationships: { build: { data: { type: 'builds', id: build.id } } } } });
    console.log('Submitted for Beta App Review.');
  } catch (error) {
    if (error.status === 409 || error.status === 422) {
      console.log(`Beta App Review: ${error.message}`);
      // Say so where it is seen: the build is in the group but waits for review.
      if (process.env.GITHUB_ACTIONS) console.log(`::warning::Build ${args.build} is in "${args.group}" but was not submitted for Beta App Review: ${error.message} Run the "TestFlight submit" workflow once the earlier build is reviewed.`);
    }
    else throw error;
  }
}
