import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, test } from 'vitest';
import app from '../app.json';

const manifestPath = path.join(process.cwd(), 'public', 'manifest.json');
const versionPath = path.join(process.cwd(), 'public', 'version.json');
const serviceWorkerPath = path.join(process.cwd(), 'public', 'service-worker.js');
const headersPath = path.join(process.cwd(), 'public', '_headers');
const appPath = path.join(process.cwd(), 'App.tsx');
const prepareExportPath = path.join(process.cwd(), 'scripts', 'prepare-web-export.mjs');
const rootAppleIconPath = path.join(process.cwd(), 'public', 'apple-touch-icon.png');
const rootApplePrecomposedIconPath = path.join(process.cwd(), 'public', 'apple-touch-icon-precomposed.png');

describe('free web launch configuration', () => {
  test('keeps web-facing app identity ready for static hosting', () => {
    expect(app.expo.name).toBe('Word7000');
    expect(app.expo.description).toContain('7000-word');
    expect(app.expo.web?.favicon).toBe('./assets/favicon.png');
  });

  test('provides a web app manifest for add-to-home-screen usage', () => {
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

    expect(manifest.name).toBe('Word7000');
    expect(manifest.short_name).toBe('Word7000');
    expect(manifest.id).toBe('/word7000-pwa-v2');
    expect(manifest.display).toBe('standalone');
    expect(manifest.start_url).toBe('/?pwa=word7000-v2');
    expect(manifest.icons.length).toBeGreaterThanOrEqual(2);
    for (const icon of manifest.icons) {
      expect(fs.existsSync(path.join(process.cwd(), 'public', icon.src.replace(/^\//, '')))).toBe(true);
    }
  });

  test('provides offline cache support for the web app shell', () => {
    const serviceWorker = fs.readFileSync(serviceWorkerPath, 'utf8');
    const headers = fs.readFileSync(headersPath, 'utf8');
    const appSource = fs.readFileSync(appPath, 'utf8');
    const prepareExport = fs.readFileSync(prepareExportPath, 'utf8');

    expect(serviceWorker).toContain('word7000-static');
    expect(serviceWorker).toContain("self.addEventListener('fetch'");
    expect(serviceWorker).toContain('self.skipWaiting');
    expect(serviceWorker).toContain('self.clients.claim');
    expect(serviceWorker).toContain("request.mode === 'navigate'");
    expect(headers).toContain('/service-worker.js');
    expect(headers).toContain('/version.json');
    expect(headers).toContain('Cache-Control: no-cache');
    expect(appSource).toContain('/service-worker.js');
    expect(appSource).toContain('/version.json');
    expect(prepareExport).toContain('rel="manifest"');
    expect(prepareExport).toContain('version.json');
  });

  test('keeps add-to-home-screen icon metadata fresh after icon changes', () => {
    const serviceWorker = fs.readFileSync(serviceWorkerPath, 'utf8');
    const prepareExport = fs.readFileSync(prepareExportPath, 'utf8');

    expect(serviceWorker).not.toContain("const APP_SHELL = ['/', '/manifest.json'");
    expect(serviceWorker).toContain('NETWORK_FIRST_PATHS');
    expect(serviceWorker).toContain("const NETWORK_FIRST_PATHS = ['/manifest.json'");
    expect(prepareExport).toContain('cacheBustInstallIcons');
    expect(prepareExport).toContain('manifest.json?v=');
    expect(prepareExport).toContain('apple-touch-icon');
    expect(prepareExport).toContain('apple-touch-icon-precomposed');
    expect(prepareExport).toContain('replaceInstallTag');
    expect(fs.existsSync(rootAppleIconPath)).toBe(true);
    expect(fs.existsSync(rootApplePrecomposedIconPath)).toBe(true);
  });

  test('provides a version endpoint for mobile web app update checks', () => {
    const version = JSON.parse(fs.readFileSync(versionPath, 'utf8'));

    expect(typeof version.version).toBe('string');
    expect(version.version.length).toBeGreaterThan(0);
  });

  test('includes a first-launch Safari add-to-home-screen guide', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('INSTALL_GUIDE_STORAGE_KEY');
    expect(appSource).toContain('Safari');
    expect(appSource).toContain('分享');
    expect(appSource).toContain('加入主畫面');
    expect(appSource).toContain('install-guide-overlay');
    expect(appSource).toContain('重新查看加入主畫面教學');
  });

  test('includes quiz session setup with selectable question counts', () => {
    const appSource = fs.readFileSync(appPath, 'utf8');

    expect(appSource).toContain('選擇題數');
    expect(appSource).toContain('開始測驗');
    expect(appSource).toContain('const quizQuestionCounts = [10, 20, 50] as const;');
    expect(appSource).toContain('{count} 題');
    expect(appSource).toContain('測驗完成');
  });
});
