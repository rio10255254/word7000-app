import fs from 'node:fs';
import path from 'node:path';
import { PNG } from 'pngjs';

const navy = [23, 32, 51, 255];
const slate = [51, 65, 85, 255];
const blue = [37, 99, 235, 255];
const white = [248, 250, 252, 255];
const light = [230, 244, 254, 255];
const transparent = [0, 0, 0, 0];

const outputs = [
  ['assets/icon.png', 1024, 'icon'],
  ['assets/adaptive-icon.png', 1024, 'icon'],
  ['assets/favicon.png', 64, 'icon'],
  ['assets/splash-icon.png', 512, 'splash'],
  ['assets/android-icon-background.png', 1024, 'background'],
  ['assets/android-icon-foreground.png', 1024, 'foreground'],
  ['assets/android-icon-monochrome.png', 1024, 'mono'],
  ['public/assets/favicon.png', 64, 'icon'],
  ['public/assets/icon.png', 1024, 'icon'],
  ['public/assets/icon-192.png', 192, 'icon'],
  ['public/assets/icon-512.png', 512, 'icon'],
  ['public/assets/maskable-icon.png', 512, 'icon'],
];

for (const [file, size, kind] of outputs) {
  const png = new PNG({ width: size, height: size });
  render(png, kind);
  const target = path.resolve(file);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, PNG.sync.write(png));
}

console.log(`Generated ${outputs.length} Word7000 brand assets`);

function render(png, kind) {
  if (kind === 'foreground' || kind === 'mono') {
    fill(png, transparent);
    drawMark(png, kind === 'mono' ? navy : navy, kind === 'mono' ? navy : blue, false);
    return;
  }

  if (kind === 'background') {
    fillGradient(png, light, [248, 250, 252, 255]);
    return;
  }

  fillGradient(png, navy, slate);
  const cardInset = kind === 'splash' ? 160 : 150;
  roundRect(png, cardInset, 218, 724, 588, 92, white);
  drawMark(png, navy, blue, true);
}

function drawMark(png, primary, accent, onCard) {
  const offsetY = onCard ? 0 : 40;
  const w = [
    [220, 330 + offsetY],
    [303, 330 + offsetY],
    [351, 594 + offsetY],
    [421, 418 + offsetY],
    [491, 594 + offsetY],
    [539, 330 + offsetY],
    [622, 330 + offsetY],
    [532, 710 + offsetY],
    [456, 710 + offsetY],
    [421, 594 + offsetY],
    [386, 710 + offsetY],
    [310, 710 + offsetY],
  ];
  const seven = [
    [632, 330 + offsetY],
    [822, 330 + offsetY],
    [822, 406 + offsetY],
    [742, 406 + offsetY],
    [668, 710 + offsetY],
    [582, 710 + offsetY],
    [662, 406 + offsetY],
    [632, 406 + offsetY],
  ];

  polygon(png, w, primary);
  polygon(png, seven, accent);
}

function fill(png, color) {
  for (let y = 0; y < png.height; y += 1) {
    for (let x = 0; x < png.width; x += 1) {
      setPixel(png, x, y, color);
    }
  }
}

function fillGradient(png, top, bottom) {
  for (let y = 0; y < png.height; y += 1) {
    const ratio = y / Math.max(1, png.height - 1);
    const color = top.map((value, index) => Math.round(value + (bottom[index] - value) * ratio));
    for (let x = 0; x < png.width; x += 1) {
      setPixel(png, x, y, color);
    }
  }
}

function roundRect(png, x, y, width, height, radius, color) {
  const scale = png.width / 1024;
  const sx = Math.round(x * scale);
  const sy = Math.round(y * scale);
  const sw = Math.round(width * scale);
  const sh = Math.round(height * scale);
  const sr = Math.round(radius * scale);

  for (let py = sy; py < sy + sh; py += 1) {
    for (let px = sx; px < sx + sw; px += 1) {
      const left = px - sx;
      const right = sx + sw - 1 - px;
      const top = py - sy;
      const bottom = sy + sh - 1 - py;
      const dx = Math.max(sr - Math.min(left, right), 0);
      const dy = Math.max(sr - Math.min(top, bottom), 0);
      if (dx * dx + dy * dy <= sr * sr) {
        setPixel(png, px, py, color);
      }
    }
  }
}

function polygon(png, basePoints, color) {
  const scale = png.width / 1024;
  const points = basePoints.map(([x, y]) => [x * scale, y * scale]);
  const minX = Math.max(0, Math.floor(Math.min(...points.map(([x]) => x))));
  const maxX = Math.min(png.width - 1, Math.ceil(Math.max(...points.map(([x]) => x))));
  const minY = Math.max(0, Math.floor(Math.min(...points.map(([, y]) => y))));
  const maxY = Math.min(png.height - 1, Math.ceil(Math.max(...points.map(([, y]) => y))));

  for (let y = minY; y <= maxY; y += 1) {
    for (let x = minX; x <= maxX; x += 1) {
      if (insidePolygon(x + 0.5, y + 0.5, points)) {
        setPixel(png, x, y, color);
      }
    }
  }
}

function insidePolygon(x, y, points) {
  let inside = false;
  for (let i = 0, j = points.length - 1; i < points.length; j = i, i += 1) {
    const [xi, yi] = points[i];
    const [xj, yj] = points[j];
    const crosses = yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi;
    if (crosses) {
      inside = !inside;
    }
  }
  return inside;
}

function setPixel(png, x, y, color) {
  const index = (png.width * y + x) * 4;
  png.data[index] = color[0];
  png.data[index + 1] = color[1];
  png.data[index + 2] = color[2];
  png.data[index + 3] = color[3];
}
