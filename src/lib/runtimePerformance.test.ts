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
