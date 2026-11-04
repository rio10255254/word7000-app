// Checks the static files the iOS app links to or fetches, served from
// public/ by the word7000-app Cloudflare Worker (wrangler.jsonc).
// `npm run build:web` runs this so a Cloudflare build command that still says
// `npm run build:web` keeps working: there is nothing to build any more.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const site = path.join(root, 'public');
const required = ['auth-native.html', 'privacy.html', 'support.html', 'ai-features.json', 'ios-update.json', '_headers'];

const missing = required.filter((file) => !fs.existsSync(path.join(site, file)));
if (missing.length) {
  throw new Error(`public/ is missing: ${missing.join(', ')}`);
}
for (const file of ['ai-features.json', 'ios-update.json']) {
  JSON.parse(fs.readFileSync(path.join(site, file), 'utf8'));
}
const wrangler = fs.readFileSync(path.join(root, 'wrangler.jsonc'), 'utf8');
if (!wrangler.includes('"directory": "./public"')) {
  throw new Error('wrangler.jsonc must serve ./public');
}
console.log(`Static site ready: ${required.length} files in public/.`);
