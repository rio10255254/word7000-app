import { describe, expect, test } from 'vitest';
import app from '../app.json';

describe('app store oriented metadata', () => {
  test('uses public-facing Word7000 identity', () => {
    expect(app.expo.name).toBe('Word7000');
    expect(app.expo.slug).toBe('word7000');
    expect(app.expo.version).toMatch(/^\d+\.\d+\.\d+$/);
  });

  test('sets basic iOS and asset configuration', () => {
    expect(app.expo.orientation).toBe('portrait');
    expect(app.expo.icon).toBe('./assets/icon.png');
    expect(app.expo.ios?.bundleIdentifier).toMatch(/^com\.[a-z0-9-]+\.[a-z0-9-]+$/);
    expect(app.expo.ios?.supportsTablet).toBe(true);
    expect(app.expo.web?.favicon).toBe('./assets/favicon.png');
  });
});
