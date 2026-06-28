import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';
import { PNG } from 'pngjs';

const colors = {
  blue: '#2563eb',
  navy: '#1e2f55',
  orange: '#f97316',
  white: '#ffffff',
};

const outputs = [
  ['assets/icon.png', 1024, 'icon'],
  ['assets/adaptive-icon.png', 1024, 'icon'],
  ['assets/favicon.png', 64, 'icon'],
  ['assets/splash-icon.png', 512, 'splash'],
  ['assets/android-icon-background.png', 1024, 'background'],
  ['assets/android-icon-foreground.png', 1024, 'foreground'],
  ['assets/android-icon-monochrome.png', 1024, 'mono'],
  ['public/apple-touch-icon.png', 180, 'icon'],
  ['public/apple-touch-icon-precomposed.png', 180, 'icon'],
  ['public/assets/favicon.png', 64, 'icon'],
  ['public/assets/apple-touch-icon.png', 180, 'icon'],
  ['public/assets/icon.png', 1024, 'icon'],
  ['public/assets/icon-192.png', 192, 'icon'],
  ['public/assets/icon-512.png', 512, 'icon'],
  ['public/assets/maskable-icon.png', 512, 'icon'],
];

const browser = await launchBrowser();

try {
  for (const [file, size, kind] of outputs) {
    const target = path.resolve(file);
    fs.mkdirSync(path.dirname(target), { recursive: true });

    if (kind === 'background') {
      writeSolidPng(target, size, hexToRgba(colors.blue));
      continue;
    }

    await renderBrandIcon(target, size, kind);
  }
} finally {
  await browser.close();
}

console.log(`Generated ${outputs.length} Word7000 brand assets`);

async function renderBrandIcon(target, size, kind) {
  const page = await browser.newPage({
    deviceScaleFactor: 1,
    viewport: { height: size, width: size },
  });

  await page.setContent(iconHtml(size, kind), { waitUntil: 'load' });
  await page.evaluate(() => document.fonts?.ready);
  await page.screenshot({
    fullPage: false,
    omitBackground: kind === 'foreground' || kind === 'mono',
    path: target,
  });
  await page.close();
}

function iconHtml(size, kind) {
  const transparent = kind === 'foreground' || kind === 'mono';
  const textColor = kind === 'mono' ? colors.navy : colors.white;
  const dotColor = kind === 'mono' ? colors.navy : colors.orange;
  const fontSize = Math.round(size * 0.366);
  const dotSize = Math.round(size * 0.22);
  const dotOffset = Math.round(size * 0.122);
  const textLift = Math.round(size * 0.006);

  return `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      html,
      body {
        background: transparent;
        height: ${size}px;
        margin: 0;
        overflow: hidden;
        width: ${size}px;
      }

      #capture {
        align-items: center;
        background: ${transparent ? 'transparent' : colors.blue};
        display: flex;
        height: ${size}px;
        justify-content: center;
        overflow: hidden;
        position: relative;
        width: ${size}px;
      }

      .mark {
        color: ${textColor};
        font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif;
        font-size: ${fontSize}px;
        font-weight: 900;
        letter-spacing: 0;
        line-height: 1;
        transform: translateY(${textLift}px);
      }

      .dot {
        background: ${dotColor};
        border-radius: 999px;
        height: ${dotSize}px;
        position: absolute;
        right: ${dotOffset}px;
        top: ${dotOffset}px;
        width: ${dotSize}px;
      }
    </style>
  </head>
  <body>
    <div id="capture">
      <div class="dot"></div>
      <div class="mark">W7</div>
    </div>
  </body>
</html>`;
}

function writeSolidPng(target, size, color) {
  const png = new PNG({ height: size, width: size });
  for (let y = 0; y < png.height; y += 1) {
    for (let x = 0; x < png.width; x += 1) {
      const index = (png.width * y + x) * 4;
      png.data[index] = color[0];
      png.data[index + 1] = color[1];
      png.data[index + 2] = color[2];
      png.data[index + 3] = color[3];
    }
  }
  fs.writeFileSync(target, PNG.sync.write(png));
}

function hexToRgba(hex) {
  const normalized = hex.replace('#', '');
  return [
    Number.parseInt(normalized.slice(0, 2), 16),
    Number.parseInt(normalized.slice(2, 4), 16),
    Number.parseInt(normalized.slice(4, 6), 16),
    255,
  ];
}

async function launchBrowser() {
  for (const channel of ['msedge', 'chrome']) {
    try {
      return await chromium.launch({ channel, headless: true });
    } catch {
      // Try the next installed browser before falling back to Playwright's bundled one.
    }
  }

  return chromium.launch({ headless: true });
}
