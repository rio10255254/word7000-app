// Draws the native app icon: the companion, a fluffy ginger kitten, with the
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
  furTop: '#FAC48F',
  furBottom: '#E38A57',
  shade: '#944929',
  stripe: '#C26638',
  cream: '#FFF2DB',
  innerEar: '#FAB3A8',
  nose: '#ED8585',
  ink: '#3B2619',
  blush: '#F28073',
};

const variants = [
  {
    file: 'icon-1024.png',
    palette: warm,
    background: `<radialGradient id="bg" cx="0.3" cy="0.2" r="1">
        <stop offset="0" stop-color="#FFF8EE"/><stop offset="0.6" stop-color="#F8E4CC"/><stop offset="1" stop-color="#EDC9A3"/>
      </radialGradient>`,
    shadow: 'rgba(150, 80, 40, 0.3)',
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

/** The whole icon: background, a soft ground shadow and the kitten. */
function iconSvg({ palette, background, shadow }) {
  const s = SIZE * 0.7;
  // The tail reaches out to the right, so the body sits a little left of centre.
  const ox = (SIZE - s) / 2 - s * 0.05;
  const oy = (SIZE - s) / 2 + s * 0.03;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${SIZE}" height="${SIZE}" viewBox="0 0 ${SIZE} ${SIZE}">
  <defs>
    ${background}
    <linearGradient id="fur" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${palette.furTop}"/><stop offset="1" stop-color="${palette.furBottom}"/>
    </linearGradient>
    <linearGradient id="shade" x1="0" y1="0.5" x2="0" y2="1">
      <stop offset="0" stop-color="${palette.shade}" stop-opacity="0"/><stop offset="1" stop-color="${palette.shade}" stop-opacity="0.3"/>
    </linearGradient>
    <linearGradient id="rim" x1="0" y1="0" x2="0" y2="0.5">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.6"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
    <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${s * 0.025}"/></filter>
    <filter id="sheen" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${s * 0.03}"/></filter>
    <filter id="ground" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${s * 0.03}"/></filter>
  </defs>
  <rect width="${SIZE}" height="${SIZE}" fill="url(#bg)"/>
  <ellipse cx="${ox + s * 0.5}" cy="${oy + s * 0.94}" rx="${s * 0.34}" ry="${s * 0.05}" fill="${shadow}" filter="url(#ground)"/>
  ${kitten(s, ox, oy, palette)}
</svg>`;
}

/** The kitten in an s × s square at (ox, oy), as Mascot.swift draws it at rest. */
function kitten(s, ox, oy, p) {
  const at = (fx, fy) => [ox + s / 2 + fx * s, oy + s / 2 + fy * s];
  const frame = (fx, fy) => [ox + fx * s, oy + fy * s];
  const parts = [];

  // Tail, curling up behind on the right, with a cream tip.
  const [bx, by] = frame(0.74, 0.84);
  const [c1x, c1y] = frame(1.1, 0.8);
  const [mx, my] = frame(1.06, 0.48);
  const [c2x, c2y] = frame(1.04, 0.3);
  const [tx, ty] = frame(0.95, 0.3);
  parts.push(`<path d="M${bx},${by} Q${c1x},${c1y} ${mx},${my} Q${c2x},${c2y} ${tx},${ty}" fill="none" stroke="url(#fur)" stroke-width="${s * 0.13}" stroke-linecap="round"/>`);
  parts.push(`<circle cx="${tx}" cy="${ty}" r="${s * 0.065}" fill="${p.cream}"/>`);

  // Ears, tilted out, pink inside.
  for (const side of [-1, 1]) {
    const w = s * 0.25;
    const h = s * 0.25;
    const [cx, cy] = at(side * 0.24, -0.395);
    const iw = s * 0.13;
    const ih = s * 0.15;
    parts.push(`<g transform="rotate(${side * 20} ${cx} ${cy + h / 2})">
      <path d="${earPath(cx - w / 2, cy - h / 2, w, h)}" fill="url(#fur)"/>
      <path d="${earPath(cx - iw / 2, cy + h / 2 - s * 0.04 - ih, iw, ih)}" fill="${p.innerEar}"/>
    </g>`);
  }

  // The fluffy body, cream chest, brow stripes, sheen and rim light.
  const [bodyX, bodyY] = at(0, 0.04);
  const fluff = fluffPath(bodyX, bodyY, s * 0.86, s * 0.78);
  parts.push(`<path d="${fluff}" fill="url(#fur)"/>`);
  parts.push(`<path d="${fluff}" fill="url(#shade)"/>`);
  const [chestX, chestY] = at(0, 0.21);
  parts.push(`<ellipse cx="${chestX}" cy="${chestY}" rx="${s * 0.22}" ry="${s * 0.15}" fill="${p.cream}" fill-opacity="0.95" filter="url(#soft)"/>`);
  for (const [dx, length, angle] of [[-0.065, 0.08, -12], [0, 0.11, 0], [0.065, 0.08, 12]]) {
    const [x, y] = at(dx, -0.315);
    parts.push(`<rect x="${x - s * 0.015}" y="${y}" width="${s * 0.03}" height="${s * length}" rx="${s * 0.015}" fill="${p.stripe}" fill-opacity="0.55" transform="rotate(${angle} ${x} ${y + (s * length) / 2})"/>`);
  }
  const [sheenX, sheenY] = at(-0.2, -0.19);
  parts.push(`<ellipse cx="${sheenX}" cy="${sheenY}" rx="${s * 0.13}" ry="${s * 0.06}" fill="#FFFFFF" fill-opacity="0.4" transform="rotate(-24 ${sheenX} ${sheenY})" filter="url(#sheen)"/>`);
  parts.push(`<path d="${fluff}" fill="none" stroke="url(#rim)" stroke-width="${Math.max(1, s * 0.012)}"/>`);

  // Front paws.
  for (const side of [-1, 1]) {
    const [x, y] = at(side * 0.155, 0.4);
    parts.push(`<ellipse cx="${x}" cy="${y}" rx="${s * 0.085}" ry="${s * 0.045}" fill="${p.cream}" stroke="${p.shade}" stroke-opacity="0.35" stroke-width="${s * 0.01}"/>`);
  }

  // Face: eyes with a highlight, cheeks, whiskers, nose and a ω mouth.
  for (const side of [-1, 1]) {
    const [ex, ey] = at(side * 0.1325, -0.02);
    parts.push(`<rect x="${ex - s * 0.0475}" y="${ey - s * 0.065}" width="${s * 0.095}" height="${s * 0.13}" rx="${s * 0.0475}" fill="${p.ink}"/>`);
    parts.push(`<circle cx="${ex + s * 0.018}" cy="${ey - s * 0.0275}" r="${s * 0.0175}" fill="#FFFFFF"/>`);
    const [kx, ky] = at(side * 0.235, 0.08);
    parts.push(`<ellipse cx="${kx}" cy="${ky}" rx="${s * 0.055}" ry="${s * 0.03}" fill="${p.blush}" fill-opacity="0.55"/>`);
    [-11, 0, 11].forEach((angle, row) => {
      const [wx, wy] = at(side * 0.33, 0.09 + (row - 1) * 0.033);
      parts.push(`<rect x="${wx - s * 0.08}" y="${wy - s * 0.0055}" width="${s * 0.16}" height="${s * 0.011}" rx="${s * 0.0055}" fill="${p.ink}" fill-opacity="0.4" transform="rotate(${side * angle} ${wx} ${wy})"/>`);
    });
  }
  const [nx, ny] = at(0, 0.07);
  const nw = s * 0.055;
  const nh = s * 0.035;
  parts.push(`<path d="M${nx - nw / 2},${ny - nh / 2} L${nx + nw / 2},${ny - nh / 2} L${nx},${ny + nh / 2}Z" fill="${p.nose}" stroke="${p.nose}" stroke-width="${s * 0.014}" stroke-linejoin="round"/>`);
  const [mouthX, mouthY] = at(0, 0.12);
  const mw = s * 0.11;
  const mh = s * 0.03;
  const top = mouthY - mh / 2;
  parts.push(`<path d="M${mouthX},${top - 0.9 * mh} L${mouthX},${top} M${mouthX - mw / 2},${top} Q${mouthX - mw / 4},${top + 2 * mh} ${mouthX},${top} Q${mouthX + mw / 4},${top + 2 * mh} ${mouthX + mw / 2},${top}" fill="none" stroke="${p.ink}" stroke-width="${s * 0.022}" stroke-linecap="round" stroke-linejoin="round"/>`);

  return parts.join('\n  ');
}

/** MascotFluff: a rounded squircle edged with little tufts of fur. */
function fluffPath(cx, cy, width, height, tufts = 26, puff = 0.045) {
  const rx = width / 2;
  const ry = height / 2;
  const point = (angle, scale) => {
    const c = Math.cos(angle);
    const s = Math.sin(angle);
    return [cx + Math.sign(c) * Math.abs(c) ** 0.8 * rx * scale, cy + Math.sign(s) * Math.abs(s) ** 0.8 * ry * scale];
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

/** MascotEar: a pointed ear with a softly rounded tip. */
function earPath(x, y, w, h) {
  return `M${x},${y + h} L${x + w * 0.38},${y + h * 0.1} Q${x + w / 2},${y - h * 0.06} ${x + w * 0.62},${y + h * 0.1} L${x + w},${y + h}Z`;
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
