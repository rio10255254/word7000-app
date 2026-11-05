// Draws the native app icon: the companion, a cheeky ginger cat, peeking over
// the app's notebook, with the
// same shapes and proportions as `ios/Word7000/Design/Mascot.swift`, in the
// three iOS home-screen appearances (light, dark and tinted). Writes opaque
// 1024 px PNGs (the App Store refuses an icon with an alpha channel).
//
//   node scripts/generate-app-icon.mjs
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';
import { encodeRgbPng, kitten } from './lib/mascot-svg.mjs';

const SIZE = 1024;
const ASSETS = 'ios/Word7000/Assets.xcassets';

const warm = {
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

// The notebook the app has always had for an icon, now in warm paper.
const book = {
  coverTop: '#FCF6EC',
  coverBottom: '#EADCC6',
};

const variants = [
  {
    folder: 'AppIcon-Leather.appiconset',
    file: 'icon-1024.png',
    palette: warm,
    book,
    // Caramel leather, as on Today's hero card, lit from the top right.
    background: ['#C98F5E', '#8A5636', '#6B4128'],
    glow: 'rgba(255, 228, 190, 0.45)',
    grain: 0.1,
  },
  {
    folder: 'AppIcon-Leather.appiconset',
    file: 'icon-1024-dark.png',
    palette: warm,
    book: { ...book, coverTop: '#EFE4D2', coverBottom: '#D6C4A8' },
    background: ['#4A3427', '#2A1E17', '#15100C'],
    glow: 'rgba(255, 200, 150, 0.16)',
    grain: 0.08,
  },
  {
    // Tinted icons are grayscale; the system colours them by brightness.
    folder: 'AppIcon-Leather.appiconset',
    file: 'icon-1024-tinted.png',
    palette: {
      furTop: '#F4F4F4',
      furBottom: '#BDBDBD',
      shade: '#5A5A5A',
      stripe: '#8A8A8A',
      cream: '#FFFFFF',
      innerEar: '#D6D6D6',
      nose: '#9A9A9A',
      ink: '#2E2E2E',
      blush: '#CFCFCF',
    },
    book: { coverTop: '#EDEDED', coverBottom: '#D0D0D0' },
    background: ['#202020', '#0C0C0C', '#000000'],
    glow: 'rgba(255, 255, 255, 0.06)',
    grain: 0,
  },
];

// The main icon: the same cat and notebook on olive green, the colour of
// Today's "goal done" card and the Instagram avatar, lighter at the top left
// like that card, with its paper grain. The notebook stays terracotta, the
// olive's complement, so the pair reads at home-screen size. The leather one
// above is the alternate.
const grayPalette = variants[2].palette;
variants.push(
  {
    folder: 'AppIcon.appiconset',
    file: 'icon-1024.png',
    palette: warm,
    book: { fill: '#C96442' },
    background: ['#93A066', '#778A53', '#5F7340'],
    glow: 'rgba(255, 248, 220, 0.22)',
    grain: 0.08,
  },
  {
    folder: 'AppIcon.appiconset',
    file: 'icon-1024-dark.png',
    palette: warm,
    book: { fill: '#D97757' },
    background: ['#4C5A36', '#36412A', '#20271A'],
    glow: 'rgba(220, 235, 190, 0.10)',
    grain: 0.06,
  },
  {
    folder: 'AppIcon.appiconset',
    file: 'icon-1024-tinted.png',
    palette: grayPalette,
    book: { fill: '#CFCFCF' },
    background: ['#202020', '#0C0C0C', '#000000'],
  },
);

// A system Chromium can stand in for Playwright's own (CHROMIUM_PATH).
const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
try {
  const page = await browser.newPage({ viewport: { width: SIZE, height: SIZE }, deviceScaleFactor: 1 });
  for (const variant of variants) {
    const svg = iconSvg(variant);
    const rgb = await page.evaluate(async ({ svg, size }) => {
      const image = new Image();
      image.src = `data:image/svg+xml;base64,${btoa(svg)}`;
      await image.decode();
      const canvas = document.createElement('canvas');
      canvas.width = size;
      canvas.height = size;
      const context = canvas.getContext('2d');
      context.drawImage(image, 0, 0, size, size);
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
    }, { svg, size: SIZE });
    const target = path.join(ASSETS, variant.folder, variant.file);
    fs.writeFileSync(target, encodeRgbPng(Buffer.from(rgb, 'base64'), SIZE, SIZE));
    console.log(`Wrote ${target}`);
  }
} finally {
  await browser.close();
}

/** The whole icon: textured leather, the notebook, and the cat peeking up
 * from behind it with its paws over the top edge and its tail curling out. */
function iconSvg({ palette, book: b, background = ['#000', '#000', '#000'], glow = 'rgba(0,0,0,0)', grain = 0, graph }) {
  // The notebook keeps the old icon's proportions and cut-outs: an upright
  // cover with the spine and three lines cut through to the leather behind.
  // The cat is sized to the book, and the two together (ear tips to the
  // book's foot) are centred in the icon with a touch more room below than
  // above, where the shadow falls, so the pair sits up rather than sinks.
  const marginTop = SIZE * 0.1;
  const marginBottom = SIZE * 0.125;
  const bookAspect = 0.58 / 0.54;
  const catScale = 1.06; // cat square / book width
  const earsAboveFace = 0.43; // ear tips above the eyes, in cat squares
  const faceAboveBook = 0.215; // eyes above the book's top edge, in cat squares
  const bookW = (SIZE - marginTop - marginBottom) / (catScale * (earsAboveFace + faceAboveBook) + bookAspect);
  const bookH = bookW * bookAspect;
  const s = bookW * catScale;
  const bookX = (SIZE - bookW) / 2;
  const bookY = SIZE - marginBottom - bookH;
  const faceY = bookY - s * faceAboveBook;
  const ox = SIZE / 2 - s / 2;
  const oy = faceY - s / 2;
  const radius = bookW * 0.1;
  const lineH = bookW * 0.059;
  const cutouts = [
    `<rect x="${bookX + bookW * 0.18}" y="${bookY - 1}" width="${bookW * 0.065}" height="${bookH + 2}" fill="black"/>`,
    ...[[0.29, 0.36], [0.45, 0.27], [0.61, 0.33]].map(([y, w]) =>
      `<rect x="${bookX + bookW * 0.36}" y="${bookY + bookH * y}" width="${bookW * w}" height="${lineH}" rx="${lineH / 2}" fill="black"/>`),
  ].join('');
  const paws = [-1, 1].map((side) => {
    const x = SIZE / 2 + side * s * 0.15;
    const y = bookY + s * 0.012;
    const toe = (dx) => `<path d="M${x + dx * s},${y + s * 0.012} L${x + dx * s},${y + s * 0.038}" stroke="${palette.shade}" stroke-opacity="0.35" stroke-width="${s * 0.008}" stroke-linecap="round"/>`;
    // A soft shadow on the cover under each paw, then the paw.
    return `<ellipse cx="${x}" cy="${y + s * 0.03}" rx="${s * 0.07}" ry="${s * 0.03}" fill="#5A3418" opacity="0.18" filter="url(#soft)"/>
    <ellipse cx="${x}" cy="${y}" rx="${s * 0.075}" ry="${s * 0.045}" fill="${palette.cream}"/>${toe(-0.025)}${toe(0.025)}`;
  }).join('');
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${SIZE}" height="${SIZE}" viewBox="0 0 ${SIZE} ${SIZE}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${background[0]}"/><stop offset="0.6" stop-color="${background[1]}"/><stop offset="1" stop-color="${background[2]}"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.82" cy="0.08" r="0.65">
      <stop offset="0" stop-color="${glow}"/><stop offset="1" stop-color="rgba(0,0,0,0)"/>
    </radialGradient>
    <radialGradient id="vignette" cx="0.5" cy="0.45" r="0.75">
      <stop offset="0.6" stop-color="rgba(0,0,0,0)"/><stop offset="1" stop-color="rgba(20,8,2,0.28)"/>
    </radialGradient>
    <linearGradient id="fur" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${palette.furTop}"/><stop offset="1" stop-color="${palette.furBottom}"/>
    </linearGradient>
    <linearGradient id="cover" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${b.coverTop}"/><stop offset="1" stop-color="${b.coverBottom}"/>
    </linearGradient>
    <linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.55"/><stop offset="0.12" stop-color="#FFFFFF" stop-opacity="0"/>
      <stop offset="0.93" stop-color="#000000" stop-opacity="0"/><stop offset="1" stop-color="#3A2010" stop-opacity="0.16"/>
    </linearGradient>
    <mask id="cuts" maskUnits="userSpaceOnUse" x="0" y="0" width="${SIZE}" height="${SIZE}">
      <rect x="${bookX}" y="${bookY}" width="${bookW}" height="${bookH}" rx="${radius}" fill="white"/>
      ${cutouts}
    </mask>
    <filter id="grain" x="0" y="0" width="100%" height="100%">
      <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed="7"/>
      <feColorMatrix type="saturate" values="0"/>
    </filter>
    <filter id="drop" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="${SIZE * 0.014}" stdDeviation="${SIZE * 0.02}" flood-color="#2A1408" flood-opacity="0.38"/>
    </filter>
    <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${SIZE * 0.006}"/></filter>
    <filter id="ground" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${SIZE * 0.02}"/></filter>
  </defs>
  ${graph ? graphPaper(graph) : `<rect width="${SIZE}" height="${SIZE}" fill="url(#bg)"/>
  <rect width="${SIZE}" height="${SIZE}" fill="url(#glow)"/>
  <rect width="${SIZE}" height="${SIZE}" fill="url(#vignette)"/>
  ${grain > 0 ? `<rect width="${SIZE}" height="${SIZE}" filter="url(#grain)" opacity="${grain}" style="mix-blend-mode:overlay"/>` : ''}
  <ellipse cx="${SIZE / 2}" cy="${bookY + bookH + SIZE * 0.02}" rx="${bookW * 0.46}" ry="${SIZE * 0.022}" fill="#1E0E05" opacity="0.35" filter="url(#ground)"/>`}
  <g filter="url(#drop)">${kitten(s, ox, oy, palette, { paws: false })}</g>
  <g filter="url(#drop)">
    <g mask="url(#cuts)">
      ${b.fill ? `<rect x="${bookX}" y="${bookY}" width="${bookW}" height="${bookH}" fill="${b.fill}"/>`
        : `<rect x="${bookX}" y="${bookY}" width="${bookW}" height="${bookH}" fill="url(#cover)"/>
      <rect x="${bookX}" y="${bookY}" width="${bookW}" height="${bookH}" fill="url(#sheen)"/>`}
    </g>
  </g>
  ${paws}
</svg>`;
}

/** A sheet of graph paper filling the icon. */
function graphPaper({ paper, line }) {
  const step = SIZE / 22;
  const lines = Array.from({ length: 23 }, (_, i) =>
    `<line x1="${i * step}" y1="0" x2="${i * step}" y2="${SIZE}" stroke="${line}" stroke-width="3"/><line x1="0" y1="${i * step}" x2="${SIZE}" y2="${i * step}" stroke="${line}" stroke-width="3"/>`).join('');
  return `<rect width="${SIZE}" height="${SIZE}" fill="${paper}"/>${lines}`;
}
