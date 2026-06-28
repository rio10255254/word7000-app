import fs from 'node:fs';
import path from 'node:path';
import { PNG } from 'pngjs';

const navy = [30, 47, 85, 255];
const blue = [37, 99, 235, 255];
const white = [255, 255, 255, 255];
const orange = [249, 115, 22, 255];
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
  ['public/assets/apple-touch-icon.png', 180, 'icon'],
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
    drawSun(png, kind === 'mono' ? navy : orange);
    drawMark(png, kind === 'mono' ? navy : white);
    return;
  }

  if (kind === 'background') {
    fillGradient(png, navy, blue);
    return;
  }

  fillGradient(png, navy, blue);
  drawSun(png, orange);
  drawMark(png, white);
}

function drawSun(png, color) {
  const scale = png.width / 1024;
  circle(png, 758 * scale, 205 * scale, 102 * scale, color);
}

function drawMark(png, color) {
  const w = [
    [282, 378],
    [328, 378],
    [360, 526],
    [400, 378],
    [450, 378],
    [488, 526],
    [520, 378],
    [562, 378],
    [520, 592],
    [466, 592],
    [425, 434],
    [382, 592],
    [335, 592],
  ];
  const seven = [
    [584, 382],
    [724, 382],
    [724, 420],
    [676, 420],
    [634, 592],
    [612, 592],
    [654, 420],
    [584, 420],
  ];

  polygon(png, w, color);
  polygon(png, seven, color);
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

function circle(png, cx, cy, radius, color) {
  const minX = Math.max(0, Math.floor(cx - radius));
  const maxX = Math.min(png.width - 1, Math.ceil(cx + radius));
  const minY = Math.max(0, Math.floor(cy - radius));
  const maxY = Math.min(png.height - 1, Math.ceil(cy + radius));
  const r2 = radius * radius;

  for (let y = minY; y <= maxY; y += 1) {
    for (let x = minX; x <= maxX; x += 1) {
      const dx = x + 0.5 - cx;
      const dy = y + 0.5 - cy;
      if (dx * dx + dy * dy <= r2) {
        setPixel(png, x, y, color);
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
