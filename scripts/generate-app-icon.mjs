// Draws the native app icon: the companion, a flat abstract cat, with the
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
const OUT = 'ios/Word7000/Assets.xcassets/AppIcon.appiconset';

const warm = {
  fur: '#EE7F4E',
  shade: '#D2603A',
  ink: '#2B1A12',
};

const variants = [
  {
    file: 'icon-1024.png',
    palette: warm,
    background: `<radialGradient id="bg" cx="0.3" cy="0.2" r="1">
        <stop offset="0" stop-color="#FFF8EE"/><stop offset="0.6" stop-color="#F8E4CC"/><stop offset="1" stop-color="#EDC9A3"/>
      </radialGradient>`,
    shadow: 'rgba(170, 80, 40, 0.28)',
  },
  {
    file: 'icon-1024-dark.png',
    palette: warm,
    background: `<radialGradient id="bg" cx="0.5" cy="0.48" r="0.75">
        <stop offset="0" stop-color="#4A3427"/><stop offset="0.6" stop-color="#2A1E17"/><stop offset="1" stop-color="#15100C"/>
      </radialGradient>`,
    shadow: 'rgba(0, 0, 0, 0.45)',
  },
  {
    // Tinted icons are grayscale; the system colours them by brightness.
    file: 'icon-1024-tinted.png',
    palette: {
      fur: '#E6E6E6',
      shade: '#B4B4B4',
      ink: '#262626',
    },
    background: `<radialGradient id="bg" cx="0.5" cy="0.5" r="0.7">
        <stop offset="0" stop-color="#1C1C1C"/><stop offset="1" stop-color="#000000"/>
      </radialGradient>`,
    shadow: 'rgba(0, 0, 0, 0.5)',
  },
];

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
    const target = path.join(OUT, variant.file);
    fs.writeFileSync(target, encodeRgbPng(Buffer.from(rgb, 'base64'), SIZE, SIZE));
    console.log(`Wrote ${target}`);
  }
} finally {
  await browser.close();
}

/** The whole icon: background, a soft ground shadow and the cat. */
function iconSvg({ palette, background, shadow }) {
  const s = SIZE * 0.74;
  // The tail rises on the right, so the body sits a little left of centre.
  const ox = (SIZE - s) / 2 - s * 0.06;
  const oy = (SIZE - s) / 2 + s * 0.02;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${SIZE}" height="${SIZE}" viewBox="0 0 ${SIZE} ${SIZE}">
  <defs>
    ${background}
    <filter id="ground" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${s * 0.03}"/></filter>
  </defs>
  <rect width="${SIZE}" height="${SIZE}" fill="url(#bg)"/>
  <ellipse cx="${ox + s * 0.5}" cy="${oy + s * 0.97}" rx="${s * 0.36}" ry="${s * 0.045}" fill="${shadow}" filter="url(#ground)"/>
  ${cat(s, ox, oy, palette)}
</svg>`;
}

/** The cat in an s × s square at (ox, oy), as Mascot.swift draws it at rest:
 * flat colour, triangle ears, a long hooked tail and its unimpressed face. */
function cat(s, ox, oy, p) {
  const at = (fx, fy) => [ox + s / 2 + fx * s, oy + s / 2 + fy * s];
  const frame = (fx, fy) => [ox + fx * s, oy + fy * s];
  const parts = [];

  // Tail (MascotTail).
  const [bx, by] = frame(0.8, 0.78);
  const [c1x, c1y] = frame(1.06, 0.74);
  const [mx, my] = frame(1.02, 0.42);
  const [c2x, c2y] = frame(0.98, 0.14);
  const [tx, ty] = frame(1.1, 0.12);
  parts.push(`<path d="M${bx},${by} Q${c1x},${c1y} ${mx},${my} Q${c2x},${c2y} ${tx},${ty}" fill="none" stroke="${p.fur}" stroke-width="${s * 0.1}" stroke-linecap="round"/>`);

  // Ears (MascotEar), tipped slightly outward.
  for (const side of [-1, 1]) {
    const w = s * 0.24;
    const h = s * 0.22;
    const [cx, base] = at(side * 0.24, -0.25);
    const apex = cx + side * 0.08 * w;
    parts.push(`<path d="M${cx - w / 2},${base} L${apex},${base - h} L${cx + w / 2},${base}Z" fill="${p.fur}" stroke="${p.fur}" stroke-width="${s * 0.03}" stroke-linejoin="round" transform="rotate(${side * 8} ${cx} ${base})"/>`);
  }

  // Feet, then the body (MascotLoaf) with its darker bottom band.
  for (const side of [-1, 1]) {
    const [x, y] = at(side * 0.17, 0.44);
    parts.push(`<rect x="${x - s * 0.07}" y="${y - s * 0.03}" width="${s * 0.14}" height="${s * 0.06}" rx="${s * 0.03}" fill="${p.shade}"/>`);
  }
  const [bodyX, bodyY] = at(0, 0.08);
  const loaf = loafPath(bodyX, bodyY, s * 0.82, s * 0.7);
  const [, bandTop] = at(0, 0.33);
  parts.push(`<clipPath id="body"><path d="${loaf}"/></clipPath>`);
  parts.push(`<path d="${loaf}" fill="${p.fur}"/>`);
  parts.push(`<rect x="${ox - s}" y="${bandTop}" width="${s * 3}" height="${s}" fill="${p.shade}" clip-path="url(#body)"/>`);

  // Heavy-lidded eyes and a small ω.
  const d = s * 0.12;
  const lid = 0.35;
  for (const side of [-1, 1]) {
    const [ex, ey] = at(side * 0.15, 0);
    const top = ey - d / 2 + d * lid;
    parts.push(`<clipPath id="eye${side}"><rect x="${ex - d}" y="${top}" width="${d * 2}" height="${d}"/></clipPath>`);
    parts.push(`<circle cx="${ex}" cy="${ey}" r="${d / 2}" fill="${p.ink}" clip-path="url(#eye${side})"/>`);
    parts.push(`<rect x="${ex - d * 0.65}" y="${top - s * 0.012}" width="${d * 1.3}" height="${s * 0.024}" rx="${s * 0.012}" fill="${p.ink}"/>`);
  }
  const [mouthX, mouthY] = at(0, 0.13);
  const mw = s * 0.1;
  const mh = s * 0.03;
  const top = mouthY - mh / 2;
  parts.push(`<path d="M${mouthX - mw / 2},${top} Q${mouthX - mw / 4},${top + 2 * mh} ${mouthX},${top} Q${mouthX + mw / 4},${top + 2 * mh} ${mouthX + mw / 2},${top}" fill="none" stroke="${p.ink}" stroke-width="${s * 0.02}" stroke-linecap="round" stroke-linejoin="round"/>`);

  return parts.join('\n  ');
}

/** MascotLoaf: a squircle, between a circle and a rounded square. */
function loafPath(cx, cy, width, height, steps = 96) {
  const points = [];
  for (let i = 0; i < steps; i += 1) {
    const angle = (2 * Math.PI * i) / steps;
    const c = Math.cos(angle);
    const s = Math.sin(angle);
    points.push(`${cx + Math.sign(c) * Math.abs(c) ** 0.6 * (width / 2)},${cy + Math.sign(s) * Math.abs(s) ** 0.6 * (height / 2)}`);
  }
  return `M${points.join(' L')}Z`;
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
