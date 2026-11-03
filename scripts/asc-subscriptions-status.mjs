#!/usr/bin/env node
// Read-only: lists the app's subscriptions, their state and their
// introductory offers (the free trial), as App Store Connect has them.
//
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… \
//   node scripts/asc-subscriptions-status.mjs --bundle com.rio.word7000
import crypto from 'node:crypto';

const bundle = process.argv[process.argv.indexOf('--bundle') + 1] || 'com.rio.word7000';
const { ASC_KEY_ID: keyId, ASC_ISSUER_ID: issuer, ASC_PRIVATE_KEY: privateKey } = process.env;
if (!keyId || !issuer || !privateKey) throw new Error('ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY are required');

const base64url = data => Buffer.from(data).toString('base64url');
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
  if (!response.ok) throw new Error(`GET ${path} → ${response.status}: ${json.errors?.map(e => e.detail ?? e.title).join('; ')}`);
  return json;
}

const app = (await api(`/v1/apps?filter[bundleId]=${encodeURIComponent(bundle)}&limit=1`)).data[0];
if (!app) throw new Error(`No app with bundle id ${bundle}`);
const groups = (await api(`/v1/apps/${app.id}/subscriptionGroups?limit=10`)).data;
for (const group of groups) {
  console.log(`Group: ${group.attributes.referenceName}`);
  const subs = (await api(`/v1/subscriptionGroups/${group.id}/subscriptions?limit=20`)).data;
  for (const sub of subs) {
    const a = sub.attributes;
    console.log(`  ${a.productId} · ${a.name} · ${a.subscriptionPeriod} · state ${a.state}`);
    const offers = await api(`/v1/subscriptions/${sub.id}/introductoryOffers?limit=200&include=territory`);
    const kinds = new Map();
    for (const offer of offers.data) {
      const o = offer.attributes;
      const key = `${o.offerMode} ${o.duration} ×${o.numberOfPeriods} from ${o.startDate ?? 'now'} to ${o.endDate ?? 'no end'}`;
      kinds.set(key, (kinds.get(key) ?? 0) + 1);
    }
    if (kinds.size === 0) console.log('    No introductory offer (no free trial)');
    for (const [key, count] of kinds) console.log(`    Intro offer: ${key} in ${count} territories`);
  }
}
