import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';

const distDir = path.resolve('dist');
const indexPath = path.join(distDir, 'index.html');
const packagePath = path.resolve('package.json');
const versionPath = path.join(distDir, 'version.json');
const manifestPath = path.join(distDir, 'manifest.json');
const serviceWorkerPath = path.join(distDir, 'service-worker.js');

if (!fs.existsSync(indexPath)) {
  throw new Error(`Missing exported index.html at ${indexPath}`);
}

let html = fs.readFileSync(indexPath, 'utf8');
const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
const buildVersion = `${packageJson.version}-${Date.now()}`;
const installIconLinks = cacheBustInstallIcons();
const runtimeConfigTag = createRuntimeConfigTag();

const metaTags = [
  '<meta name="description" content="A simple offline 7000-word English vocabulary app for daily learning and review." />',
  '<meta name="theme-color" content="#172033" />',
  '<meta name="apple-mobile-web-app-capable" content="yes" />',
  '<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />',
  '<meta name="apple-mobile-web-app-title" content="Word7000" />',
];
const installTags = [
  `<link rel="manifest" href="${installIconLinks.manifestHref}" />`,
  `<link rel="apple-touch-icon" sizes="180x180" href="${installIconLinks.appleTouchIconHref}" />`,
  `<link rel="apple-touch-icon-precomposed" sizes="180x180" href="${installIconLinks.appleTouchIconHref}" />`,
];

for (const tag of metaTags) {
  const marker = tag.match(/name="([^"]+)"/)?.[1];

  if (marker && !html.includes(marker)) {
    html = html.replace('</head>', `  ${tag}\n</head>`);
  }
}

html = ensureViewportFit(html);
if (runtimeConfigTag) {
  html = replaceRuntimeConfigTag(html, runtimeConfigTag);
}
html = replaceInstallTag(html, /<link\b(?=[^>]*rel=["']manifest["'])[^>]*\/?>/gi, installTags[0]);
html = replaceInstallTag(html, /<link\b(?=[^>]*rel=["']apple-touch-icon(?:-precomposed)?["'])[^>]*\/?>/gi, installTags.slice(1).join('\n  '));

fs.writeFileSync(indexPath, html, 'utf8');
refreshServiceWorkerCacheName(buildVersion);
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

function cacheBustInstallIcons() {
  if (!fs.existsSync(manifestPath)) {
    throw new Error(`Missing web manifest at ${manifestPath}`);
  }

  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  manifest.icons = manifest.icons.map((icon) => ({
    ...icon,
    src: cacheBustAsset(icon.src),
  }));
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');

  const appleTouchSource = fs.existsSync(path.join(distDir, 'apple-touch-icon.png'))
    ? '/apple-touch-icon.png'
    : fs.existsSync(path.join(distDir, 'assets', 'apple-touch-icon.png'))
      ? '/assets/apple-touch-icon.png'
      : '/assets/icon.png';
  const appleTouchIconHref = cacheBustAsset(appleTouchSource);
  const manifestHash = fileHash(manifestPath);

  return {
    appleTouchIconHref,
    manifestHref: `/manifest.json?v=${manifestHash}`,
  };
}

function replaceInstallTag(source, matcher, tag) {
  const withoutPrevious = source.replace(matcher, '');
  return withoutPrevious.replace('</head>', `  ${tag}\n</head>`);
}

function createRuntimeConfigTag() {
  const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL?.trim();
  const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY?.trim();

  if (!supabaseUrl || !supabaseAnonKey) {
    return '';
  }

  const payload = JSON.stringify({
    supabaseAnonKey,
    supabaseUrl,
  }).replace(/</g, '\\u003c');

  return `<script>globalThis.__WORD7000_CONFIG__=${payload};</script>`;
}

function replaceRuntimeConfigTag(source, tag) {
  const withoutPrevious = source.replace(
    /\s*<script>globalThis\.__WORD7000_CONFIG__=.*?<\/script>/gs,
    '',
  );
  return withoutPrevious.replace('</head>', `  ${tag}\n</head>`);
}

function ensureViewportFit(source) {
  const viewportMatcher = /<meta\s+name=["']viewport["']\s+content=["']([^"']*)["']\s*\/?>/i;
  const match = source.match(viewportMatcher);

  if (!match) {
    return source.replace(
      '</head>',
      '  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />\n</head>',
    );
  }

  const viewportContent = match[1];
  if (viewportContent.includes('viewport-fit=cover')) {
    return source;
  }

  return source.replace(
    viewportMatcher,
    `<meta name="viewport" content="${viewportContent}, viewport-fit=cover" />`,
  );
}

function cacheBustAsset(src) {
  const relativeSource = src.replace(/^\//, '').split('?')[0];
  const sourcePath = path.join(distDir, relativeSource);
  if (!fs.existsSync(sourcePath)) {
    throw new Error(`Missing install icon asset at ${sourcePath}`);
  }

  const parsed = path.parse(relativeSource);
  const hash = fileHash(sourcePath);
  const versionedRelative = path.join(parsed.dir, `${parsed.name}-${hash}${parsed.ext}`).replaceAll(path.sep, '/');
  fs.copyFileSync(sourcePath, path.join(distDir, versionedRelative));
  return `/${versionedRelative}`;
}

function fileHash(filePath) {
  return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex').slice(0, 12);
}

function refreshServiceWorkerCacheName(version) {
  if (!fs.existsSync(serviceWorkerPath)) {
    return;
  }

  const safeVersion = version.replace(/[^a-zA-Z0-9_-]/g, '-');
  const serviceWorker = fs
    .readFileSync(serviceWorkerPath, 'utf8')
    .replace(/word7000-static-v[0-9a-zA-Z_-]+/g, `word7000-static-${safeVersion}`);
  fs.writeFileSync(serviceWorkerPath, serviceWorker, 'utf8');
}
