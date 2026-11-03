// The companion cat as SVG, with the same shapes and proportions as
// `ios/Word7000/Design/Mascot.swift`, and an opaque PNG writer. Shared by the
// app icon and the App Store promotional images.
import zlib from 'node:zlib';

/** The cat in an s × s square at (ox, oy), as Mascot.swift draws it at rest:
 * a round lump with a tuft at each cheek and on top, and its unimpressed face. */
export function kitten(s, ox, oy, p, { paws = true } = {}) {
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
export function encodeRgbPng(rgb, width, height) {
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
