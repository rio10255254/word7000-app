import fs from 'node:fs';
import path from 'node:path';
import { PNG } from 'pngjs';
import { describe, expect, test } from 'vitest';

const desktopIconPath = path.join(process.cwd(), 'public', 'apple-touch-icon.png');
const brandMarkPath = path.join(process.cwd(), 'src', 'components', 'BrandMark.tsx');
const appSourcePath = path.join(process.cwd(), 'App.tsx');
const errorBoundaryPath = path.join(process.cwd(), 'src', 'components', 'AppErrorBoundary.tsx');

describe('brand icon assets', () => {
  test('matches the Dynamic Island closed-book style for home-screen installs', () => {
    const png = PNG.sync.read(fs.readFileSync(desktopIconPath));
    const background = rgbaAt(png, 12, 12);
    const cover = rgbaAt(png, 45, 45);
    const spine = rgbaAt(png, 64, 90);
    const coverLine = rgbaAt(png, 85, 70);
    const coverBody = rgbaAt(png, 110, 100);

    expect(background).toEqual([37, 99, 235, 255]);
    expect(cover).toEqual([255, 255, 255, 255]);
    expect(spine).toEqual([37, 99, 235, 255]);
    expect(coverLine).toEqual([37, 99, 235, 255]);
    expect(coverBody).toEqual([255, 255, 255, 255]);
    expect(minimumAlpha(png)).toBe(255);
  });

  test('uses the same book mark in launch, onboarding, and recovery screens', () => {
    const brandMark = fs.readFileSync(brandMarkPath, 'utf8');
    const appSource = fs.readFileSync(appSourcePath, 'utf8');
    const errorBoundary = fs.readFileSync(errorBoundaryPath, 'utf8');

    expect(brandMark).toContain("backgroundColor: '#2563EB'");
    expect(brandMark).toContain("backgroundColor: '#FFFFFF'");
    expect(appSource).toContain('<BrandMark size={82} style={styles.launchIcon} />');
    expect(appSource).toContain('<BrandMark size={48} style={[styles.installGuideLogo, themeStyles?.installGuideLogo]} />');
    expect(errorBoundary).toContain('<BrandMark size={64} style={styles.mark} />');
    expect(appSource).not.toContain('launchIconText');
    expect(appSource).not.toContain('installGuideLogoText');
  });
});

function rgbaAt(png: PNG, x: number, y: number): number[] {
  const index = (png.width * y + x) * 4;
  return Array.from(png.data.slice(index, index + 4));
}

function minimumAlpha(png: PNG): number {
  let minimum = 255;
  for (let index = 3; index < png.data.length; index += 4) {
    minimum = Math.min(minimum, png.data[index]);
  }
  return minimum;
}
