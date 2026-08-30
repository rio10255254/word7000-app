import { describe, expect, test } from 'vitest';
import app from '../app.json';
import eas from '../eas.json';
import packageJson from '../package.json';

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
    expect(app.expo.scheme).toBe('word7000');
    expect(app.expo.runtimeVersion).toEqual({ policy: 'appVersion' });
    expect(app.expo.ios?.usesAppleSignIn).toBe(true);
    expect(app.expo.ios?.supportsTablet).toBe(false);
    expect(app.expo.web?.favicon).toBe('./assets/favicon.png');
  });

  test('defines EAS build profiles for TestFlight and App Store preparation', () => {
    expect(eas.build.development.channel).toBe('development');
    expect(eas.build.preview.channel).toBe('preview');
    expect(eas.build.preview.distribution).toBe('internal');
    expect(eas.build.production.channel).toBe('production');
    expect(eas.build.production.autoIncrement).toBe(true);
    expect(eas.submit.production.ios.ascAppId).toBe('6786934889');
  });

  test('uses the Hermes memory-fix runtime without dropping older supported iPhones', () => {
    expect(packageJson.dependencies.expo).toMatch(/^~57\./);
    expect(packageJson.dependencies['react-native']).toBe('0.86.3');
    expect(packageJson.dependencies['react-native-reanimated']).toBe('4.5.1');
    expect(packageJson.dependencies['expo-battery']).toMatch(/^~57\./);
    expect(app.expo.version).toBe('1.4.1');
  });
});
