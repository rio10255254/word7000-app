// Draws the native app icon: the companion, a cheeky ginger cat, peeking over
// the app's notebook, with the
// same shapes and proportions as `ios/Word7000/Design/Mascot.swift`, in the
// three iOS home-screen appearances (light, dark and tinted). Writes opaque
// 1024 px PNGs (the App Store refuses an icon with an alpha channel).
//
//   node scripts/generate-app-icon.mjs
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { chromium } from 'playwright';

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
    folder: 'AppIcon.appiconset',
    file: 'icon-1024.png',
    palette: warm,
    book,
    // Caramel leather, as on Today's hero card, lit from the top right.
    background: ['#C98F5E', '#8A5636', '#6B4128'],
    glow: 'rgba(255, 228, 190, 0.45)',
    grain: 0.1,
  },
  {
    folder: 'AppIcon.appiconset',
    file: 'icon-1024-dark.png',
    palette: warm,
    book: { ...book, coverTop: '#EFE4D2', coverBottom: '#D6C4A8' },
    background: ['#4A3427', '#2A1E17', '#15100C'],
    glow: 'rgba(255, 200, 150, 0.16)',
    grain: 0.08,
  },
  {
    // Tinted icons are grayscale; the system colours them by brightness.
    folder: 'AppIcon.appiconset',
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

// The paper collage style's icon (chosen in Settings > App style): the same
// cat and notebook on plain graph paper, the notebook in terracotta. Nothing
// else, so it stays clear at home-screen size.
const grayPalette = variants[2].palette;
variants.push(
  {
    folder: 'AppIcon-Collage.appiconset',
    file: 'icon-1024.png',
    palette: warm,
    book: { fill: '#C96442' },
    graph: { paper: '#F1F2EA', line: '#C6D6CF' },
  },
  {
    folder: 'AppIcon-Collage.appiconset',
    file: 'icon-1024-dark.png',
    palette: warm,
    book: { fill: '#D97757' },
    graph: { paper: '#22231F', line: '#38443F' },
  },
  {
    folder: 'AppIcon-Collage.appiconset',
    file: 'icon-1024-tinted.png',
    palette: grayPalette,
    book: { fill: '#CFCFCF' },
    graph: { paper: '#000000', line: '#262626' },
  },
);

const browser = await chromium.launch();
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

/** The cat in an s × s square at (ox, oy), as Mascot.swift draws it at rest:
 * a round lump with a tuft at each cheek and on top, and its unimpressed face. */
function kitten(s, ox, oy, p, { paws = true } = {}) {
  const at = (fx, fy) => [ox + s / 2 + fx * s, oy + s / 2 + fy * s];
  const frame = (fx, fy) => [ox + fx * s, oy + fy * s];
  const parts = [];

  // Tail (MascotTail).
  const [bx, by] = frame(0.74, 0.86);
  const [cx1, cy1] = frame(1.04, 0.84);
  const [tx, ty] = frame(0.98, 0.52);
  parts.push(`<path d="M${bx},${by} Q${cx1},${cy1} ${tx},${ty}" fill="none" stroke="url(#fur)" stroke-width="${s * 0.12}" stroke-linecap="round"/>`);

  // Ears (MascotEar), pink inside.
  for (const side of [-1, 1]) {
    const w = s * 0.22;
    const h = s * 0.2;
    const [cx, cy] = at(side * 0.23, -0.33);
    const iw = s * 0.11;
    const ih = s * 0.12;
    parts.push(`<g transform="rotate(${side * 18} ${cx} ${cy + h / 2})">
      <path d="${earPath(cx - w / 2, cy - h / 2, w, h)}" fill="url(#fur)"/>
      <path d="${earPath(cx - iw / 2, cy + h / 2 - s * 0.035 - ih, iw, ih)}" fill="${p.innerEar}"/>
    </g>`);
  }

  // The lump (MascotFluff, barely ruffled, settled flat underneath).
  const [bodyX, bodyY] = at(0, 0.07);
  parts.push(`<path d="${fluffPath(bodyX, bodyY, s * 0.9, s * 0.74, 20, 0.015, 0.9, 0.92)}" fill="url(#fur)"/>`);
  for (const side of [-1, 1]) {
    // Cheek tufts (MascotCheekTuft).
    const w = s * 0.065;
    const h = s * 0.105;
    const [cx, cy] = at(side * 0.4325, 0.13);
    const pt = (fx, fy) => `${cx + side * (fx - 0.5) * w},${cy + (fy - 0.5) * h}`;
    parts.push(`<path d="M${pt(0, 0)} L${pt(1, 0.28)} L${pt(0.3, 0.52)} L${pt(0.95, 0.78)} L${pt(0, 1)}Z" fill="${p.furTop}"/>`);
  }
  // Top tuft (MascotTuft).
  const tuftW = s * 0.08;
  const tuftH = s * 0.09;
  const [tuftCX, tuftTop] = at(0, -0.36);
  const tuft = (fx, fy) => `${tuftCX - tuftW / 2 + fx * tuftW},${tuftTop + fy * tuftH}`;
  parts.push(`<path d="M${tuft(0, 1)} Q${tuft(0.2, 0.1)} ${tuft(0.5, 0)} Q${tuft(0.45, 0.5)} ${tuft(0.7, 0.3)} Q${tuft(0.8, 0.7)} ${tuft(1, 1)}Z" fill="${p.furTop}"/>`);
  // Cream chest with its tuft.
  const [chestX, chestY] = at(0, 0.29);
  parts.push(`<ellipse cx="${chestX}" cy="${chestY}" rx="${s * 0.17}" ry="${s * 0.1}" fill="${p.cream}"/>`);
  const zw = s * 0.09;
  const zh = s * 0.04;
  const zTop = chestY - s * 0.1 - zh + s * 0.012;
  parts.push(`<path d="M${chestX - zw / 2},${zTop + zh} L${chestX - zw / 4},${zTop} L${chestX},${zTop + zh} L${chestX + zw / 4},${zTop} L${chestX + zw / 2},${zTop + zh}Z" fill="${p.cream}"/>`);
  // Paws.
  for (const side of paws ? [-1, 1] : []) {
    const [x, y] = at(side * 0.15, 0.42);
    parts.push(`<ellipse cx="${x}" cy="${y}" rx="${s * 0.07}" ry="${s * 0.035}" fill="${p.cream}"/>`);
  }

  // Face: heavy-lidded eyes with a glint, two whiskers a side, nose, ω.
  const d = s * 0.11;
  const lid = 0.4;
  for (const side of [-1, 1]) {
    const [ex, ey] = at(side * 0.14, 0);
    const top = ey - d / 2 + d * lid;
    parts.push(`<clipPath id="eye${side}"><rect x="${ex - d}" y="${top}" width="${d * 2}" height="${d}"/></clipPath>`);
    parts.push(`<g clip-path="url(#eye${side})"><circle cx="${ex}" cy="${ey}" r="${d / 2}" fill="${p.ink}"/><circle cx="${ex + d * 0.21}" cy="${top + d * 0.19}" r="${d * 0.13}" fill="#FFFFFF"/></g>`);
    parts.push(`<rect x="${ex - d * 0.65}" y="${top - s * 0.012}" width="${d * 1.3}" height="${s * 0.024}" rx="${s * 0.012}" fill="${p.ink}"/>`);
    [-8, 8].forEach((angle, row) => {
      const [wx, wy] = at(side * 0.33, 0.1 + (row - 0.5) * 0.035);
      parts.push(`<rect x="${wx - s * 0.06}" y="${wy - s * 0.005}" width="${s * 0.12}" height="${s * 0.01}" rx="${s * 0.005}" fill="${p.ink}" fill-opacity="0.35" transform="rotate(${side * angle} ${wx} ${wy})"/>`);
    });
  }
  const [nx, ny] = at(0, 0.075);
  const nw = s * 0.045;
  const nh = s * 0.028;
  parts.push(`<path d="M${nx - nw / 2},${ny - nh / 2} L${nx + nw / 2},${ny - nh / 2} L${nx},${ny + nh / 2}Z" fill="${p.nose}" stroke="${p.nose}" stroke-width="${s * 0.012}" stroke-linejoin="round"/>`);
  const [mouthX, mouthY] = at(0, 0.125);
  const mw = s * 0.09;
  const mh = s * 0.026;
  const top = mouthY - mh / 2;
  parts.push(`<path d="M${mouthX - mw / 2},${top} Q${mouthX - mw / 4},${top + 2 * mh} ${mouthX},${top} Q${mouthX + mw / 4},${top + 2 * mh} ${mouthX + mw / 2},${top}" fill="none" stroke="${p.ink}" stroke-width="${s * 0.02}" stroke-linecap="round" stroke-linejoin="round"/>`);

  return parts.join('\n  ');
}

/** MascotFluff: a squircle edged with little tufts, optionally settled flat underneath. */
function fluffPath(cx, cy, width, height, tufts = 26, puff = 0.06, roundness = 0.8, settle = 1) {
  const rx = width / 2;
  const ry = height / 2;
  const point = (angle, scale) => {
    const c = Math.cos(angle);
    const s = Math.sin(angle);
    let y = Math.sign(s) * Math.abs(s) ** roundness;
    if (y > 0) y *= settle;
    return [cx + Math.sign(c) * Math.abs(c) ** roundness * rx * scale, cy + y * ry * scale];
  };
  const step = (2 * Math.PI) / tufts;
  const [x0, y0] = point(0, 1 - puff);
  let d = `M${x0},${y0}`;
  for (let i = 0; i < tufts; i += 1) {
    const from = i * step;
    const [qx, qy] = point(from + step / 2, 1 + puff);
    const [ex, ey] = point(from + step, 1 - puff);
    d += ` Q${qx},${qy} ${ex},${ey}`;
  }
  return `${d}Z`;
}

/** MascotEar: an ear with a softly rounded tip. */
function earPath(x, y, w, h) {
  return `M${x},${y + h} L${x + w * 0.36},${y + h * 0.14} Q${x + w / 2},${y - h * 0.04} ${x + w * 0.64},${y + h * 0.14} L${x + w},${y + h}Z`;
}

/** An 8-bit RGB PNG, no alpha channel. */
function encodeRgbPng(rgb, width, height) {
  const stride = width * 3;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y += 1) {
    raw[y * (stride + 1)] = 0;
    rgb.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride);
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8; // bit depth
  header[9] = 2; // truecolour
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', header),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function chunk(type, data) {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(zlib.crc32(body) >>> 0);
  return Buffer.concat([length, body, crc]);
}
