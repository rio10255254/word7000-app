#!/usr/bin/env node
// Prints the next build number for an app version: one more than the
// highest build App Store Connect has for that version (expired builds
// included, as Apple never accepts a number twice), or 1 for a new version.
//
//   ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… \
//   node scripts/next-build-number.mjs --bundle com.rio.word7000 --version 2.0.2
import crypto from 'node:crypto';

const args = Object.fromEntries(process.argv.slice(2).reduce((pairs, value, index, all) => {
  if (value.startsWith('--')) pairs.push([value.slice(2), all[index + 1] ?? '']);
  return pairs;
}, []));
const { ASC_KEY_ID: keyId, ASC_ISSUER_ID: issuer, ASC_PRIVATE_KEY: privateKey } = process.env;
if (!keyId || !issuer || !privateKey) throw new Error('ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY are required');
for (const name of ['bundle', 'version']) if (!args[name]) throw new Error(`--${name} is required`);

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
  const text = await response.text();
  if (!response.ok) throw new Error(`GET ${path} → ${response.status}: ${text}`);
  return JSON.parse(text);
}
const q = encodeURIComponent;

const app = (await api(`/v1/apps?filter[bundleId]=${q(args.bundle)}&limit=1`)).data[0];
if (!app) throw new Error(`No app with bundle id ${args.bundle}`);

let highest = 0;
let path = `/v1/builds?filter[app]=${app.id}&filter[preReleaseVersion.version]=${q(args.version)}&fields[builds]=version&limit=200`;
while (path) {
  const page = await api(path);
  for (const build of page.data) {
    const number = Number(build.attributes?.version);
    if (Number.isSafeInteger(number) && number > highest) highest = number;
  }
  const next = page.links?.next;
  path = next ? next.replace('https://api.appstoreconnect.apple.com', '') : '';
}
console.error(`Highest build of ${args.version} on App Store Connect: ${highest || 'none'}.`);
process.stdout.write(String(highest + 1));
