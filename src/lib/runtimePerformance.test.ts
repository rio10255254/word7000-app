import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, test } from 'vitest';
import { buildRuntimePerformanceProfile, parseIosMajorVersion } from './runtimePerformanceCore';

describe('runtime performance profile', () => {
  test('parses iOS major versions from native platform values', () => {
    expect(parseIosMajorVersion('18.6.2')).toBe(18);
    expect(parseIosMajorVersion(26)).toBe(26);
    expect(parseIosMajorVersion('unknown')).toBeNull();
  });

  test('keeps Liquid Glass off on iOS 18 and earlier', () => {
    expect(buildRuntimePerformanceProfile({
      iosMajorVersion: 18,
      lowPowerMode: false,
      reduceMotion: false,
      reduceTransparency: false,
    })).toMatchObject({ isLegacyIos: true, supportsLiquidGlass: false });
  });

  test('disables expensive effects for accessibility and low power settings', () => {
    expect(buildRuntimePerformanceProfile({
      iosMajorVersion: 26,
      lowPowerMode: true,
      reduceMotion: false,
      reduceTransparency: false,
    })).toMatchObject({ conserveResources: true, supportsLiquidGlass: false });
    expect(buildRuntimePerformanceProfile({
      iosMajorVersion: 26,
      lowPowerMode: false,
      reduceMotion: false,
      reduceTransparency: true,
    })).toMatchObject({ supportsLiquidGlass: false });
  });
});

describe('runtime performance provider on web', () => {
  test('does not call AccessibilityInfo methods react-native-web leaves out', () => {
    const webAccessibilityInfo = fs.readFileSync(
      path.join(process.cwd(), 'node_modules', 'react-native-web', 'dist', 'exports', 'AccessibilityInfo', 'index.js'),
      'utf8',
    );
    const providerSource = fs.readFileSync(path.join(process.cwd(), 'src', 'lib', 'runtimePerformance.tsx'), 'utf8');

    // Calling the missing method threw on first paint and the whole web app
    // fell through to the error boundary.
    expect(webAccessibilityInfo).not.toContain('isReduceTransparencyEnabled');
    expect(providerSource).toContain("typeof AccessibilityInfo.isReduceTransparencyEnabled === 'function'");
  });
});
