import fs from 'node:fs';
import path from 'node:path';

const distDir = path.resolve('dist');
const indexPath = path.join(distDir, 'index.html');
const packagePath = path.resolve('package.json');
const versionPath = path.join(distDir, 'version.json');

if (!fs.existsSync(indexPath)) {
  throw new Error(`Missing exported index.html at ${indexPath}`);
}

let html = fs.readFileSync(indexPath, 'utf8');

const tags = [
  '<meta name="description" content="A simple offline 7000-word English vocabulary app for daily learning and review." />',
  '<meta name="theme-color" content="#172033" />',
  '<meta name="apple-mobile-web-app-capable" content="yes" />',
  '<meta name="apple-mobile-web-app-title" content="Word7000" />',
  '<link rel="manifest" href="/manifest.json" />',
  '<link rel="apple-touch-icon" href="/assets/icon.png" />',
];

for (const tag of tags) {
  const marker = tag.includes('rel="manifest"')
    ? 'rel="manifest"'
    : tag.includes('apple-touch-icon')
      ? 'apple-touch-icon'
      : tag.match(/name="([^"]+)"/)?.[1];

  if (marker && !html.includes(marker)) {
    html = html.replace('</head>', `  ${tag}\n</head>`);
  }
}

fs.writeFileSync(indexPath, html, 'utf8');
const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
const buildVersion = `${packageJson.version}-${Date.now()}`;
fs.writeFileSync(
  versionPath,
  `${JSON.stringify(
    {
      version: buildVersion,
      builtAt: new Date().toISOString(),
    },
    null,
    2,
  )}\n`,
  'utf8',
);
console.log(`Prepared web export at ${distDir}`);
