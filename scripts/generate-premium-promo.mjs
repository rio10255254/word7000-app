// Draws the App Store promotional images for the two Premium subscriptions:
// the companion cat (the same drawing as the app icon and Mascot.swift)
// peeking over a terracotta membership card on the collage's paper desk, with
// a rubber stamp for the term. No prices and no translated words, so one image
// serves every storefront. Writes opaque 1024 px PNGs (Apple refuses
// transparency) to exports/premium-promo/.
//
//   node scripts/generate-premium-promo.mjs
//   CHROMIUM_PATH=/path/to/chrome node scripts/generate-premium-promo.mjs
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';
import { encodeRgbPng, kitten } from './lib/mascot-svg.mjs';

const SIZE = 1024;
const OUT = 'exports/premium-promo';
const FONT = 'https://cdn.jsdelivr.net/npm/@fontsource/fraunces@5.0.0/files';

const palette = {
  furTop: '#FAC48F',
  furBottom: '#E38A57',
  shade: '#944929',
  stripe: '#C26638',
  cream: '#FFF2DB',
  innerEar: '#FAB3A8',
  nose: '#ED8585',
  ink: '#2B1A12',
  blush: '#F28073',
};

const variants = [
  { file: 'premium-monthly.png', number: '1', term: 'MONTH' },
  { file: 'premium-yearly.png', number: '12', term: 'MONTHS' },
];

/** A four-pointed sparkle with curved sides, like SF Symbols' sparkles. */
function sparkle(cx, cy, r, fill, extra = '') {
  const k = r * 0.16;
  return `<path d="M${cx},${cy - r} Q${cx + k},${cy - k} ${cx + r},${cy} Q${cx + k},${cy + k} ${cx},${cy + r} Q${cx - k},${cy + k} ${cx - r},${cy} Q${cx - k},${cy - k} ${cx},${cy - r}Z" fill="${fill}" ${extra}/>`;
}

/** A strip of masking tape with torn ends. */
function tape(x, y, w, h, angle) {
  const teeth = (x0, dir) => Array.from({ length: 7 }, (_, i) => `${x0 + dir * (i % 2 ? 5 : 0)},${(h / 6) * i}`).join(' ');
  return `<g transform="translate(${x} ${y}) rotate(${angle})" filter="url(#tapeShadow)">
    <polygon points="${teeth(0, 1)} ${teeth(w, -1).split(' ').reverse().join(' ')}" fill="#EFE3C6" fill-opacity="0.9"/>
    <rect x="6" y="0" width="${w - 12}" height="${h}" fill="url(#tapeSheen)"/>
  </g>`;
}

function page({ number, term }) {
  const s = 430; // the cat's square, as in the icon
  const card = { x: 172, y: 430, w: 680, h: 432, r: 48 };
  const faceY = card.y - s * 0.215;
  const ox = SIZE / 2 - s / 2;
  const oy = faceY - s / 2;
  const paws = [-1, 1].map((side) => {
    const x = SIZE / 2 + side * s * 0.15;
    const y = card.y + s * 0.012;
    const toe = (dx) => `<path d="M${x + dx * s},${y + s * 0.012} L${x + dx * s},${y + s * 0.038}" stroke="${palette.shade}" stroke-opacity="0.35" stroke-width="${s * 0.008}" stroke-linecap="round"/>`;
    return `<ellipse cx="${x}" cy="${y + s * 0.03}" rx="${s * 0.07}" ry="${s * 0.03}" fill="#5A3418" opacity="0.22" filter="url(#soft)"/>
      <ellipse cx="${x}" cy="${y}" rx="${s * 0.075}" ry="${s * 0.045}" fill="${palette.cream}"/>${toe(-0.025)}${toe(0.025)}`;
  }).join('');
  const halftone = [];
  for (let row = 0; row < 9; row += 1) {
    for (let col = 0; col < 12; col += 1) {
      const x = card.x + card.w - 250 + col * 21 + (row % 2) * 10.5;
      const y = card.y + 26 + row * 18;
      const fade = Math.max(0, 1 - Math.hypot(col - 11, row) / 11);
      if (fade > 0.05) halftone.push(`<circle cx="${x}" cy="${y}" r="${2.6 * fade + 0.6}" fill="#FFF2DB" opacity="${0.28 * fade}"/>`);
    }
  }
  const ruled = Array.from({ length: 16 }, (_, i) => `<line x1="0" y1="${60 + i * 34}" x2="620" y2="${60 + i * 34}" stroke="#BCD0DE" stroke-width="2"/>`).join('');
  const grid = Array.from({ length: 23 }, (_, i) => {
    const p = i * (SIZE / 22);
    return `<line x1="${p}" y1="0" x2="${p}" y2="${SIZE}"/><line x1="0" y1="${p}" x2="${SIZE}" y2="${p}"/>`;
  }).join('');
  const stamp = { cx: card.x + card.w - 18, cy: card.y + card.h + 6, r: 92 };

  return `<!doctype html><html><head><meta charset="utf-8"><style>
  @font-face { font-family: Fraunces; font-weight: 700; src: url(${FONT}/fraunces-latin-700-normal.woff2) format('woff2'); }
  @font-face { font-family: Fraunces; font-weight: 600; font-style: italic; src: url(${FONT}/fraunces-latin-600-italic.woff2) format('woff2'); }
  @font-face { font-family: Fraunces; font-weight: 500; src: url(${FONT}/fraunces-latin-500-normal.woff2) format('woff2'); }
  html, body { margin: 0; width: ${SIZE}px; height: ${SIZE}px; overflow: hidden; background: #F4EDE1; }
  svg { display: block; }
  </style></head><body>
  <svg xmlns="http://www.w3.org/2000/svg" width="${SIZE}" height="${SIZE}" viewBox="0 0 ${SIZE} ${SIZE}">
  <defs>
    <radialGradient id="desk" cx="0.5" cy="0.42" r="0.78">
      <stop offset="0" stop-color="#FCF8F1"/><stop offset="0.65" stop-color="#F1E8D9"/><stop offset="1" stop-color="#DCCBB0"/>
    </radialGradient>
    <linearGradient id="fur" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${palette.furTop}"/><stop offset="1" stop-color="${palette.furBottom}"/></linearGradient>
    <linearGradient id="card" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#E2875D"/><stop offset="0.55" stop-color="#C9623F"/><stop offset="1" stop-color="#A4442A"/>
    </linearGradient>
    <linearGradient id="sheen" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.32"/><stop offset="0.38" stop-color="#FFFFFF" stop-opacity="0.04"/>
      <stop offset="0.39" stop-color="#FFFFFF" stop-opacity="0"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="foil" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#FFF6E4"/><stop offset="0.5" stop-color="#FFE3B8"/><stop offset="1" stop-color="#FFF1D6"/>
    </linearGradient>
    <linearGradient id="tapeSheen" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.35"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#FFE9C7" stop-opacity="0.55"/><stop offset="1" stop-color="#FFE9C7" stop-opacity="0"/>
    </radialGradient>
    <filter id="grain" x="0" y="0" width="100%" height="100%">
      <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="11"/>
      <feColorMatrix type="saturate" values="0"/>
    </filter>
    <filter id="cardShadow" x="-20%" y="-20%" width="140%" height="150%">
      <feDropShadow dx="0" dy="18" stdDeviation="22" flood-color="#3A1A08" flood-opacity="0.34"/>
      <feDropShadow dx="0" dy="3" stdDeviation="3" flood-color="#3A1A08" flood-opacity="0.25"/>
    </filter>
    <filter id="paperShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#3A2410" flood-opacity="0.18"/>
    </filter>
    <filter id="catShadow" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#2A1408" flood-opacity="0.28"/>
    </filter>
    <filter id="tapeShadow" x="-20%" y="-50%" width="140%" height="200%">
      <feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="#3A2410" flood-opacity="0.18"/>
    </filter>
    <filter id="stampInk" x="-10%" y="-10%" width="120%" height="120%">
      <feTurbulence type="fractalNoise" baseFrequency="1.6" numOctaves="1" seed="4" result="n"/>
      <feColorMatrix in="n" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -0.9 1.2" result="speckle"/>
      <feComposite in="SourceGraphic" in2="speckle" operator="in"/>
    </filter>
    <filter id="emboss" x="-10%" y="-10%" width="120%" height="130%">
      <feDropShadow dx="0" dy="2" stdDeviation="0.6" flood-color="#6E2A14" flood-opacity="0.55"/>
    </filter>
    <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6"/></filter>
    <clipPath id="cardClip"><rect x="${card.x}" y="${card.y}" width="${card.w}" height="${card.h}" rx="${card.r}"/></clipPath>
  </defs>

  <!-- The desk: warm paper, faint graph lines, grain and a soft vignette. -->
  <rect width="${SIZE}" height="${SIZE}" fill="url(#desk)"/>
  <g stroke="#D6D9CC" stroke-width="2" opacity="0.55">${grid}</g>
  <rect width="${SIZE}" height="${SIZE}" filter="url(#grain)" opacity="0.09" style="mix-blend-mode:multiply"/>

  <!-- A ruled notebook page underneath, askew. -->
  <g transform="translate(206 300) rotate(-7 310 260)" filter="url(#paperShadow)">
    <rect width="620" height="560" fill="#FBF8F2"/>
    ${ruled}
    <line x1="64" y1="0" x2="64" y2="560" stroke="#E39787" stroke-width="2.5"/>
    <rect width="620" height="560" filter="url(#grain)" opacity="0.06" style="mix-blend-mode:multiply"/>
  </g>

  <!-- A warm glow behind the cat. -->
  <circle cx="${SIZE / 2}" cy="${card.y - 60}" r="300" fill="url(#glow)"/>

  <g transform="rotate(-2.5 ${SIZE / 2} ${card.y + card.h / 2})">
    <g filter="url(#catShadow)">${kitten(s, ox, oy, palette, { paws: false })}</g>

    <!-- The membership card. -->
    <g filter="url(#cardShadow)">
      <rect x="${card.x}" y="${card.y}" width="${card.w}" height="${card.h}" rx="${card.r}" fill="url(#card)"/>
    </g>
    <g clip-path="url(#cardClip)">
      <rect x="${card.x}" y="${card.y}" width="${card.w}" height="${card.h}" filter="url(#grain)" opacity="0.12" style="mix-blend-mode:overlay"/>
      ${halftone.join('')}
      <rect x="${card.x}" y="${card.y}" width="${card.w}" height="${card.h}" fill="url(#sheen)"/>
    </g>
    <rect x="${card.x + 16}" y="${card.y + 16}" width="${card.w - 32}" height="${card.h - 32}" rx="${card.r - 14}" fill="none" stroke="#FFE9CC" stroke-opacity="0.38" stroke-width="2"/>

    <text x="${card.x + 58}" y="${card.y + 112}" font-family="Fraunces" font-weight="500" font-size="27" letter-spacing="9" fill="#FFF1DA" fill-opacity="0.82">WORDCAT</text>
    <g filter="url(#emboss)">
      ${sparkle(card.x + card.w - 210, card.y + 190, 92, 'url(#foil)')}
      ${sparkle(card.x + card.w - 108, card.y + 104, 34, 'url(#foil)')}
      ${sparkle(card.x + card.w - 300, card.y + 96, 22, 'url(#foil)', 'opacity="0.85"')}
      <text x="${card.x + 54}" y="${card.y + card.h - 70}" font-family="Fraunces" font-weight="600" font-style="italic" font-size="118" fill="url(#foil)">Premium</text>
    </g>

    ${paws}

    <!-- Tape holding the card down. -->
    ${tape(card.x - 34, card.y + 28, 150, 46, -38)}
    ${tape(card.x + card.w - 70, card.y - 30, 140, 44, 32)}

    <!-- The rubber stamp for the term. -->
    <g transform="rotate(-14 ${stamp.cx} ${stamp.cy})">
      <circle cx="${stamp.cx}" cy="${stamp.cy}" r="${stamp.r + 6}" fill="#FBF6EC" filter="url(#paperShadow)"/>
      <g filter="url(#stampInk)" fill="none" stroke="#B4472B">
        <circle cx="${stamp.cx}" cy="${stamp.cy}" r="${stamp.r - 6}" stroke-width="7"/>
        <circle cx="${stamp.cx}" cy="${stamp.cy}" r="${stamp.r - 20}" stroke-width="2.5"/>
        <text x="${stamp.cx}" y="${stamp.cy + (number.length > 1 ? 18 : 22)}" text-anchor="middle" font-family="Fraunces" font-weight="700" font-size="${number.length > 1 ? 76 : 86}" fill="#B4472B" stroke="none">${number}</text>
        <text x="${stamp.cx}" y="${stamp.cy + 47}" text-anchor="middle" font-family="Fraunces" font-weight="700" font-size="14" letter-spacing="3" fill="#B4472B" stroke="none">${term}</text>
        ${sparkle(stamp.cx, stamp.cy - 57, 9, '#B4472B', 'stroke="none"')}
      </g>
    </g>
  </g>
  </svg></body></html>`;
}

fs.mkdirSync(OUT, { recursive: true });
const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
try {
  const tab = await browser.newPage({ viewport: { width: SIZE, height: SIZE }, deviceScaleFactor: 1 });
  for (const variant of variants) {
    await tab.setContent(page(variant), { waitUntil: 'networkidle' });
    await tab.evaluate(() => document.fonts.ready);
    const shot = await tab.screenshot({ type: 'png' });
    // Back through a canvas to drop the alpha channel.
    const rgb = await tab.evaluate(async ({ png, size }) => {
      const image = new Image();
      image.src = `data:image/png;base64,${png}`;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = size;
      canvas.height = size;
      const context = canvas.getContext('2d');
      context.drawImage(image, 0, 0);
      const { data } = context.getImageData(0, 0, size, size);
      const out = new Uint8Array(size * size * 3);
      for (let i = 0, j = 0; i < data.length; i += 4, j += 3) {
        out[j] = data[i];
        out[j + 1] = data[i + 1];
        out[j + 2] = data[i + 2];
      }
      let binary = '';
      for (let i = 0; i < out.length; i += 0x8000) binary += String.fromCharCode(...out.subarray(i, i + 0x8000));
      return btoa(binary);
    }, { png: shot.toString('base64'), size: SIZE });
    const target = path.join(OUT, variant.file);
    fs.writeFileSync(target, encodeRgbPng(Buffer.from(rgb, 'base64'), SIZE, SIZE));
    console.log(`Wrote ${target}`);
  }
} finally {
  await browser.close();
}
