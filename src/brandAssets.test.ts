import fs from 'node:fs';
import path from 'node:path';
import { PNG } from 'pngjs';
import { describe, expect, test } from 'vitest';

const desktopIconPath = path.join(process.cwd(), 'public', 'apple-touch-icon.png');

describe('brand icon assets', () => {
  test('matches the launch animation icon style for home-screen installs', () => {
    const png = PNG.sync.read(fs.readFileSync(desktopIconPath));
    const center = rgbaAt(png, 12, 12);
    const dot = rgbaAt(png, 146, 34);
    const topBar = whitePixelsInRow(png, 82, 80);
    const lowerDiagonal = whitePixelsInRow(png, 104, 100);

    expect(center).toEqual([37, 99, 235, 255]);
    expect(dot).toEqual([249, 115, 22, 255]);
    expect(topBar.length).toBeGreaterThanOrEqual(24);
    expect(lowerDiagonal.length).toBeGreaterThanOrEqual(8);
    expect(Math.min(...lowerDiagonal)).toBeLessThan(Math.max(...topBar) - 12);
  });
});

function rgbaAt(png: PNG, x: number, y: number): number[] {
  const index = (png.width * y + x) * 4;
  return Array.from(png.data.slice(index, index + 4));
}

function whitePixelsInRow(png: PNG, y: number, minX: number): number[] {
  const pixels: number[] = [];
  for (let x = minX; x < png.width; x += 1) {
    const index = (png.width * y + x) * 4;
    const alpha = png.data[index + 3];
    const red = png.data[index];
    const green = png.data[index + 1];
    const blue = png.data[index + 2];
    if (alpha > 200 && red > 230 && green > 230 && blue > 230) {
      pixels.push(x);
    }
  }
  return pixels;
}
