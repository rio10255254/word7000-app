import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, test } from 'vitest';
import app from '../app.json';

const root = process.cwd();
const read = (...parts: string[]) => fs.readFileSync(path.join(root, ...parts), 'utf8');

describe('scanned word banks', () => {
  test('recognises text on the device with Apple Vision in Traditional Chinese and English', () => {
    const swift = read('modules', 'word-scanner', 'ios', 'WordScannerModule.swift');
    const moduleConfig = JSON.parse(read('modules', 'word-scanner', 'expo-module.config.json'));
    const bridge = read('modules', 'word-scanner', 'index.ts');

    expect(moduleConfig.apple.modules).toEqual(['WordScannerModule']);
    expect(swift).toContain('import Vision');
    expect(swift).toContain('VNRecognizeTextRequest()');
    expect(swift).toContain('request.recognitionLanguages = requested');
    expect(swift).toContain('"y": Double(1 - box.maxY)');
    expect(bridge).toContain("['zh-Hant', 'en-US']");
    // Older TestFlight builds and the web have no native module; they must
    // degrade to "unavailable" rather than crash on import.
    expect(bridge).toContain('requireOptionalNativeModule');
  });

  test('ships the native module sources to EAS builds', () => {
    const easIgnore = read('.easignore');

    // An unanchored "ios/" would also drop modules/word-scanner/ios.
    expect(easIgnore).toMatch(/^\/ios\/$/m);
    expect(easIgnore).toMatch(/^\/android\/$/m);
    expect(easIgnore).not.toMatch(/^ios\/$/m);
  });

  test('explains camera and photo access, and asks for no microphone', () => {
    const picker = app.expo.plugins.find(
      (plugin) => Array.isArray(plugin) && plugin[0] === 'expo-image-picker',
    ) as [string, Record<string, unknown>] | undefined;

    expect(picker?.[1].cameraPermission).toContain('照片不會上傳');
    expect(picker?.[1].photosPermission).toContain('照片不會上傳');
    expect(picker?.[1].microphonePermission).toBe(false);
  });

  test('keeps scanning behind sign-in and registers the route', () => {
    const route = read('src', 'app', 'scan.tsx');
    const layout = read('src', 'app', '_layout.tsx');
    const appSource = read('App.tsx');

    expect(layout).toContain('<Stack.Screen name="scan" />');
    expect(route).toContain("bridge.actions.requestAccountUpgrade('customSets')");
    expect(appSource).toContain("requestAccountUpgrade('customSets', () => router.push('/scan'))");
    // Scanned words never leak into the core 7000-word bank.
    expect(appSource).toContain('customSetState.customWords.filter((word) => !isScannedWordId(word.id))');
    // Words typed by hand into a scanned bank stay in that bank too.
    expect(appSource).toContain('if (targetSet.wordIds.some(isScannedWordId)) {');
  });
});
