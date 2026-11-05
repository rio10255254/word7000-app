// Draws the cat for the lock screen card and the Dynamic Island: the same
// companion as the app icon (scripts/lib/mascot-svg.mjs), on a transparent
// background with a soft shadow, at 2x and 3x for a 64-point frame.
//
//   node scripts/generate-live-activity-cat.mjs
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';
import { kitten } from './lib/mascot-svg.mjs';

const OUT = 'ios/Word7000Widgets/Assets.xcassets/LiveCat.imageset';
const POINTS = 64;
const warm = {
  furTop: '#FAC48F', furBottom: '#E38A57', shade: '#944929', stripe: '#C26638', cream: '#FFF2DB',
  innerEar: '#FAB3A8', nose: '#ED8585', ink: '#2B1A12', blush: '#F28073',
};

function catSvg(size) {
  // The tail reaches a little past the cat's square, so the square is inset.
  const s = size * 0.84;
  const ox = size * 0.06;
  const oy = size * 0.05;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
  <defs>
    <linearGradient id="fur" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${warm.furTop}"/><stop offset="1" stop-color="${warm.furBottom}"/>
    </linearGradient>
    <filter id="drop" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="${size * 0.02}" stdDeviation="${size * 0.025}" flood-color="#0E1208" flood-opacity="0.45"/>
    </filter>
  </defs>
  <g filter="url(#drop)">${kitten(s, ox, oy, warm)}</g>
</svg>`;
}

fs.mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
try {
  const images = [];
  for (const scale of [2, 3]) {
    const size = POINTS * scale;
    const page = await browser.newPage({ viewport: { width: size, height: size }, deviceScaleFactor: 1 });
    await page.setContent(`<html><body style="margin:0;background:transparent">${catSvg(size)}</body></html>`);
    const file = `live-cat@${scale}x.png`;
    await page.locator('svg').screenshot({ path: path.join(OUT, file), omitBackground: true });
    await page.close();
    images.push({ idiom: 'universal', scale: `${scale}x`, filename: file });
    console.log(`Wrote ${path.join(OUT, file)}`);
  }
  images.unshift({ idiom: 'universal', scale: '1x' });
  fs.writeFileSync(path.join(OUT, 'Contents.json'), `${JSON.stringify({ images, info: { author: 'xcode', version: 1 } }, null, 2)}\n`);
  fs.writeFileSync(path.join(path.dirname(OUT), 'Contents.json'), `${JSON.stringify({ info: { author: 'xcode', version: 1 } }, null, 2)}\n`);
} finally {
  await browser.close();
}
